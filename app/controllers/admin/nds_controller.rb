require "csv"

module Admin
  class NdsController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin!

    # ── Konstanten (vor private – in Ruby immer öffentlich, aber hier der
    #    Übersichtlichkeit halber an einem Ort) ──────────────────────────────
    CSV_OPTS         = { headers: true, col_sep: ";", encoding: "bom|utf-8" }.freeze
    MAX_UPLOAD_BYTES = 5.megabytes

    BASPO_AWK_HEADERS   = %w[PERSONENNUMMER FUNKTION DATUM AKTIVITAETSTYP ZEIT DAUER ORT].freeze
    BASPO_AWK_DURATIONS = [ 45, 60, 75, 90, 120, 150, 180, 210, 240, 270, 300 ].freeze
    AWK_MAX_MINUTES     = 90

    # ── Public Actions ──────────────────────────────────────────────────────

    def show
      @courses = Course.where(is_js_training: true).order(:title)
      # Importergebnis aus Cache laden (nur der Schlüssel steht im Cookie)
      if (key = flash[:nds_result_key]).present?
        @nds_results = Rails.cache.read(key)
      end
      # Präsenzkontrolle-Prüfung aus Cache laden
      if (key = flash[:nds_check_key]).present?
        @attendance_check = Rails.cache.read(key)
      end
    end

    # Schritt 5 – Präsenzkontrolle auf Vollständigkeit prüfen
    def check_attendance
      course_id    = params[:course_id]
      date_from    = safe_date(params[:date_from]) || Date.today.beginning_of_month
      date_to      = safe_date(params[:date_to])   || Date.today
      effective_to = [ date_to, Date.today ].min

      js_courses = course_id.present? \
        ? Course.where(id: course_id, is_js_training: true)
        : Course.where(is_js_training: true)

      js_courses = js_courses
                     .includes(:course_registrations,
                               training_sessions: :attendances)
                     .order(:title)

      missing_by_course = []

      js_courses.each do |course|
        reg_count = course.course_registrations.count { |r| r.status == "bestätigt" }
        next if reg_count == 0

        sessions = course.training_sessions
                         .reject(&:is_canceled?)
                         .select { |s| s.start_time && s.start_time.to_date.between?(date_from, effective_to) }
                         .sort_by(&:start_time)

        missing_sessions = sessions.select do |s|
          s.attendances.none? { |a| a.status == "anwesend" }
        end

        next if missing_sessions.empty?

        missing_by_course << {
          course_id:    course.id,
          course_title: course.title,
          sessions:     missing_sessions.map do |s|
            {
              id:      s.id,
              date:    s.start_time.strftime("%d.%m.%Y"),
              weekday: I18n.l(s.start_time, format: "%A"),
              time:    s.start_time.strftime("%H:%M")
            }
          end
        }
      end

      results = {
        date_from:     date_from,
        date_to:       date_to,
        effective_to:  effective_to,
        course_id:     course_id,
        checked_count: js_courses.count,
        missing:       missing_by_course,
        all_done:      missing_by_course.empty?
      }

      cache_key = "nds_check_#{SecureRandom.uuid}"
      Rails.cache.write(cache_key, results, expires_in: 10.minutes)
      flash[:nds_check_key] = cache_key

      redirect_to admin_nds_path
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

      # Pass 1 – Header validieren + Duplikate erkennen (streaming)
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

          ahv = normalize_ahv(row["AHV_NR"])
          next if ahv.nil?

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
        extra  = dup_lines.size > 5 ? " …" : ""
        return redirect_to(admin_nds_path,
          alert: "Doppelte AHV-Einträge in Zeile(n) #{sample}#{extra} – Import abgebrochen.")
      end

      # Nur Teilnehmer laden, deren normalisierte AHV in der CSV vorkommt –
      # gezielte WHERE-Abfrage statt vollständiger Tabellen-Scan.
      # Danach reines In-Memory-Lookup – kein N+1 in der Import-Schleife.
      participants_by_ahv = build_participants_by_ahv(ahv_first_line.keys)

      # Pass 2 – Teilnehmer aktualisieren (streaming)
      updated       = 0
      not_found     = []
      not_found_all = 0
      errors        = []

      CSV.foreach(upload.path, **CSV_OPTS).with_index(2) do |row, line|
        raw_ahv   = row["AHV_NR"]&.strip
        js_number = row["PERSONENNUMMER"]&.strip
        next if raw_ahv.blank?  # Zeile ohne AHV-Feld: stillschweigend überspringen

        ahv = normalize_ahv(raw_ahv)
        if ahv.nil?
          errors << "Zeile #{line}: ungültiges AHV-Format – übersprungen"
          next
        end

        full_name   = [ row["VORNAME"]&.strip, row["NAME"]&.strip ].compact.join(" ")
        display     = full_name.presence || "Zeile #{line}"
        participant = participants_by_ahv[ahv]

        if participant.nil?
          not_found_all += 1
          not_found << display
        elsif participant.update(js_person_number: js_number.presence)
          updated += 1
        else
          errors << "Zeile #{line}: #{participant.errors.full_messages.join(', ')}"
        end
      end

      # Ergebnisse im Cache speichern – nur der Schlüssel (~36 Zeichen) landet
      # im Session-Cookie, die Detaildaten nie.
      results = { updated: updated, not_found: not_found, not_found_count: not_found_all, errors: errors }
      cache_key = "nds_import_#{SecureRandom.uuid}"
      Rails.cache.write(cache_key, results, expires_in: 10.minutes)
      flash[:nds_result_key] = cache_key

      redirect_to admin_nds_path
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

    # Lädt nur die Teilnehmer, deren normalisierte AHV in der übergebenen Liste
    # vorkommt (ein gezielter IN-Query). Gibt Hash normalisierte_AHV → Participant.
    def build_participants_by_ahv(normalized_ahvs)
      result = {}
      Participant.where(ahv_number: normalized_ahvs).each do |p|
        key = normalize_ahv(p.ahv_number)
        result[key] = p if key
      end
      result
    end

    # Normalisiert AHV-Nummern in unser DB-Format 756.XXXX.XXXX.XX.
    # Akzeptiert sowohl "756.1234.5678.90" als auch "7561234567890".
    # Gibt nil zurück wenn das Format ungültig ist (nicht 13 Ziffern).
    def normalize_ahv(raw)
      digits = raw.to_s.gsub(/\D/, "")
      return nil unless digits.length == 13
      "#{digits[0, 3]}.#{digits[3, 4]}.#{digits[7, 4]}.#{digits[11, 2]}"
    end

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
