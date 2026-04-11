require "csv"

module Admin
  class NdsController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin!

    CSV_OPTS = { headers: true, col_sep: ";", encoding: "bom|utf-8" }.freeze
    MAX_UPLOAD_BYTES = 5.megabytes

    def show
      @courses = Course.order(:title)
      if (key = flash[:nds_import_cache_key]).present?
        @import_results = Rails.cache.read(key)
      end
    end

    # Schritt 1 – BASPO Personenimport CSV herunterladen
    def export_persons
      course       = params[:course_id].present? ? Course.find(params[:course_id]) : nil
      participants = course ? course.participants.includes(:user, :courses) : Participant.includes(:user, :courses)
      suffix       = course ? course.title.parameterize : "alle-kurse"

      csv_data = ExportProfile.new.generate_baspo_person_csv(participants)
      filename = "nds-personenimport-#{suffix}-#{Date.today.iso8601}.csv"
      send_data csv_data, filename: filename, type: "text/csv; charset=utf-8-bom", disposition: "attachment"
    end

    # Schritt 4 – NDS-Rückfile importieren, AHV-Matching, js_person_number aktualisieren
    def import_persons
      upload = params[:csv_file]
      return redirect_to(admin_nds_path, alert: "Bitte eine CSV-Datei auswählen.") if upload.blank?
      return redirect_to(admin_nds_path, alert: "Die Datei ist zu gross (max. 5 MB).") if upload.size > MAX_UPLOAD_BYTES

      # Pass 1 – Header prüfen + Duplikate erkennen (streaming, kein vollständiges Einlesen)
      csv_error      = nil
      ahv_first_line = {}
      dup_lines      = []

      begin
        CSV.foreach(upload.path, **CSV_OPTS).with_index(2) do |row, line|
          if line == 2
            unless row.headers.any? { |h| h&.strip == "AHV_NR" } &&
                   row.headers.any? { |h| h&.strip == "PERSONENNUMMER" }
              csv_error = "CSV-Datei hat nicht das erwartete Format (Spalten AHV_NR und PERSONENNUMMER fehlen)."
              break
            end
          end

          ahv = row["AHV_NR"]&.strip
          next if ahv.blank?

          if ahv_first_line.key?(ahv)
            dup_lines << line
          else
            ahv_first_line[ahv] = line
          end
        end
      rescue CSV::MalformedCSVError => e
        csv_error = "Ungültige CSV-Datei: #{e.message}"
      end

      return redirect_to(admin_nds_path, alert: csv_error) if csv_error

      if dup_lines.any?
        sample = dup_lines.first(5).join(", ")
        return redirect_to(admin_nds_path,
          alert: "Fehler: Doppelte AHV-Einträge in Zeile(n) #{sample}#{dup_lines.size > 5 ? ' …' : ''} – Import abgebrochen.")
      end

      # Pass 2 – Teilnehmer aktualisieren (erneut streaming)
      results = { updated: 0, skipped: 0, errors: [] }

      CSV.foreach(upload.path, **CSV_OPTS).with_index(2) do |row, line|
        ahv       = row["AHV_NR"]&.strip
        js_number = row["PERSONENNUMMER"]&.strip
        next if ahv.blank?

        participant = Participant.find_by(ahv_number: ahv)
        if participant.nil?
          results[:skipped] += 1
          results[:errors] << "Zeile #{line}: kein Teilnehmer gefunden – übersprungen"
        elsif participant.update(js_person_number: js_number.presence)
          results[:updated] += 1
        else
          results[:errors] << "Zeile #{line}: #{participant.errors.full_messages.join(', ')}"
        end
      end

      # Ergebnisse im Cache speichern – nur der Schlüssel landet im Cookie
      cache_key = "nds_import_#{SecureRandom.uuid}"
      Rails.cache.write(cache_key, results, expires_in: 10.minutes)
      flash[:nds_import_cache_key] = cache_key

      redirect_to admin_nds_path,
        notice: "Import abgeschlossen: #{results[:updated]} aktualisiert, #{results[:skipped]} übersprungen, #{results[:errors].size} Fehler."
    end

    # Schritt 5 – BASPO AWK CSV herunterladen (Dauer max. 90 Min.)
    def export_awk
      if params[:course_id].blank?
        redirect_to admin_nds_path, alert: "Bitte einen Kurs auswählen."
        return
      end

      course     = Course.find(params[:course_id])
      date_from  = safe_date(params[:date_from]) || Date.today.beginning_of_month
      date_to    = safe_date(params[:date_to])   || Date.today
      date_range = date_from..date_to

      csv_data = generate_awk_csv_capped(course, date_range)
      filename = "nds-awk-#{course.title.parameterize}-#{Date.today.iso8601}.csv"
      send_data csv_data, filename: filename, type: "text/csv; charset=utf-8-bom", disposition: "attachment"
    end

    private

    BASPO_AWK_HEADERS   = %w[PERSONENNUMMER FUNKTION DATUM AKTIVITAETSTYP ZEIT DAUER ORT].freeze
    BASPO_AWK_DURATIONS = [ 45, 60, 75, 90, 120, 150, 180, 210, 240, 270, 300 ].freeze
    AWK_MAX_MINUTES     = 90

    # AWK CSV mit Dauer-Kappung auf max. 90 Minuten
    def generate_awk_csv_capped(course, date_range)
      bom      = "\xEF\xBB\xBF"
      sessions = course.training_sessions
                       .where(is_canceled: false)
                       .where(start_time: date_range.first.beginning_of_day..date_range.last.end_of_day)
                       .order(:start_time)
                       .includes(:attendances)
                       .to_a

      registrations = course.course_registrations
                            .where(status: "bestätigt")
                            .includes(:participant, :attendances)
                            .to_a

      csv = CSV.generate(col_sep: ";", row_sep: "\r\n", headers: BASPO_AWK_HEADERS, write_headers: true) do |out|
        sessions.each do |session|
          datum   = session.start_time.strftime("%d.%m.%Y")
          zeit    = session.start_time.strftime("%H:%M")
          dauer   = awk_duration_capped(session)
          ort     = course.location.to_s
          att_map = session.attendances.index_by(&:course_registration_id)

          registrations.each do |reg|
            next unless att_map[reg.id]&.status == "anwesend"
            out << [ reg.participant.js_person_number, "Teilnehmer/in", datum, "Training", zeit, dauer, ort ]
          end
          # Trainer werden in der NDS manuell erfasst und haben keine js_person_number –
          # Zeilen ohne PERSONENNUMMER würden vom NDS-Import abgelehnt.
        end
      end
      bom + csv
    end

    def safe_date(str)
      Date.parse(str) if str.present?
    rescue ArgumentError
      nil
    end

    def awk_duration_capped(session)
      return nil unless session.start_time && session.end_time
      minutes = [ ((session.end_time - session.start_time) / 60).round, AWK_MAX_MINUTES ].min
      BASPO_AWK_DURATIONS.min_by { |d| (d - minutes).abs }
    end
  end
end
