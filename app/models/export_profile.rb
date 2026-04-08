require "csv"

class ExportProfile < ApplicationRecord
  belongs_to :course, optional: true

  # ── Konstanten ──────────────────────────────────────────────────────────────

  EXPORT_TYPES = {
    "teilnehmerliste"     => "Teilnehmerliste",
    "anwesenheitsliste"   => "Anwesenheitsliste",
    "baspo_personenimport" => "BASPO Personenimport (J+S)"
  }.freeze

  SCHEDULES = {
    "none"    => "Kein automatischer Export",
    "daily"   => "Täglich",
    "weekly"  => "Wöchentlich",
    "monthly" => "Monatlich"
  }.freeze

  COL_SEPS = {
    ";"  => "Semikolon  ;",
    ","  => "Komma  ,",
    "\t" => "Tabulator  ⇥",
    "|"  => "Pipe  |"
  }.freeze

  ROW_SEPS = {
    "\\n"    => 'LF  \n  (Unix/Mac)',
    "\\r\\n" => 'CRLF  \r\n  (Windows/Excel)'
  }.freeze

  QUOTE_CHARS = {
    '"' => 'Anführungszeichen  "',
    "'" => "Apostroph  '",
    ""  => "Keines"
  }.freeze

  AVAILABLE_FIELDS = {
    "last_name"        => "Nachname",
    "first_name"       => "Vorname",
    "date_of_birth"    => "Geburtsdatum",
    "user_email"       => "E-Mail",
    "phone_number"     => "Telefon",
    "gender"           => "Geschlecht",
    "ahv_number"       => "AHV-Nummer",
    "js_person_number" => "J+S Personennummer",
    "nationality"      => "Nationalität",
    "mother_tongue"    => "Muttersprache",
    "street"           => "Strasse",
    "house_number"     => "Hausnummer",
    "zip_code"         => "PLZ",
    "city"             => "Ort",
    "country"          => "Land",
    "courses"          => "Eingeschriebene Kurse"
  }.freeze

  DATE_RANGE_TYPES = {
    "current_semester" => "Aktuelles Semester",
    "last_semester"    => "Letztes Semester",
    "full_year"        => "Ganzes Jahr",
    "custom"           => "Benutzerdefiniert"
  }.freeze

  DATE_COLUMN_FORMATS = {
    "%d.%m.%Y" => "DD.MM.YYYY (z. B. 07.04.2026)",
    "%d.%m."   => "DD.MM. (z. B. 07.04.)",
    "kw"       => "KW + Wochentag (z. B. KW15 Dienstag)"
  }.freeze

  ATTENDANCE_SYMBOL_PRESETS = {
    "symbols" => { "anwesend" => "✓", "abwesend" => "✗", "abgemeldet" => "–", "keine" => "○" },
    "letters" => { "anwesend" => "A", "abwesend" => "N", "abgemeldet" => "E", "keine" => "–" },
    "full"    => { "anwesend" => "anwesend", "abwesend" => "abwesend", "abgemeldet" => "abgemeldet", "keine" => "–" }
  }.freeze

  SORT_OPTIONS = {
    "last_name"       => "Nachname",
    "first_name"      => "Vorname",
    "attendance_rate" => "Anwesenheitsquote"
  }.freeze

  SUMMARY_COLUMNS = {
    "present_count"   => "Anz. anwesend",
    "absent_count"    => "Anz. abwesend",
    "excused_count"   => "Anz. abgemeldet",
    "attendance_rate" => "Anwesenheitsquote %"
  }.freeze

  # ── Validierungen ───────────────────────────────────────────────────────────

  validates :name,        presence: true
  validates :export_type, inclusion: { in: EXPORT_TYPES.keys }
  validates :format,      inclusion: { in: %w[csv xlsx pdf] }
  validates :schedule,    inclusion: { in: SCHEDULES.keys }
  validates :col_sep,     inclusion: { in: COL_SEPS.keys }
  validates :row_sep,     inclusion: { in: ROW_SEPS.keys }

  validate :at_least_one_field, if: -> { export_type == "teilnehmerliste" }
  validates :course_id,
            presence: { message: "ist für Anwesenheitslisten erforderlich" },
            if: -> { export_type == "anwesenheitsliste" }

  validates :recipient_email,
            format: { with: URI::MailTo::EMAIL_REGEXP },
            allow_blank: true
  validates :recipient_email,
            presence: { message: "wird benötigt wenn ein Intervall gewählt ist" },
            if: -> { schedule != "none" }

  # ── CSV-Hilfsmethoden (Teilnehmerliste) ─────────────────────────────────────

  def effective_col_sep
    col_sep.presence || ";"
  end

  def effective_row_sep
    row_sep == "\\r\\n" ? "\r\n" : "\n"
  end

  def effective_quote_char
    quote_char.presence || '"'
  end

  def generate_csv(participants)
    opts = {
      col_sep:       effective_col_sep,
      row_sep:       effective_row_sep,
      quote_char:    effective_quote_char,
      headers:       include_header? ? csv_headers : false,
      write_headers: include_header?
    }
    CSV.generate(**opts) do |csv|
      participants.each { |p| csv << csv_row(p) }
    end
  end

  def csv_headers
    fields.reject(&:blank?).map { |f| AVAILABLE_FIELDS[f] || f }
  end

  def csv_row(participant)
    fields.reject(&:blank?).map do |field|
      case field
      when "last_name"     then participant.last_name
      when "first_name"    then participant.first_name
      when "date_of_birth" then participant.date_of_birth&.strftime("%d.%m.%Y")
      when "phone_number"  then participant.phone_number
      when "gender"        then participant.gender
      when "ahv_number"    then participant.ahv_number
      when "user_email"    then participant.user.email
      when "courses"       then participant.courses.map(&:title).join(", ")
      end
    end
  end

  def scheduled?
    schedule != "none"
  end

  # ── Anwesenheitsliste: Datum-Bereich ────────────────────────────────────────

  def effective_date_range
    today = Date.today
    case date_range_type
    when "current_semester"
      if today.month <= 6
        Date.new(today.year, 1, 1)..Date.new(today.year, 6, 30)
      else
        Date.new(today.year, 7, 1)..Date.new(today.year, 12, 31)
      end
    when "last_semester"
      if today.month <= 6
        Date.new(today.year - 1, 7, 1)..Date.new(today.year - 1, 12, 31)
      else
        Date.new(today.year, 1, 1)..Date.new(today.year, 6, 30)
      end
    when "full_year"
      Date.new(today.year, 1, 1)..Date.new(today.year, 12, 31)
    else
      from = date_from || today.beginning_of_month
      to   = date_to   || today
      from..to
    end
  end

  # ── Anwesenheitsliste: CSV ───────────────────────────────────────────────────

  def generate_attendance_csv(course, date_range)
    sessions      = sessions_for_course(course, date_range)
    registrations = sorted_registrations(course)
    syms          = effective_symbols

    opts = {
      col_sep:       effective_col_sep,
      row_sep:       effective_row_sep,
      quote_char:    effective_quote_char,
      headers:       include_header? ? attendance_headers(sessions) : false,
      write_headers: include_header?
    }
    CSV.generate(**opts) do |csv|
      registrations.each do |reg|
        att_map = reg.attendances.index_by(&:training_session_id)
        row = fixed_column_values(reg.participant)
        sessions.each { |s| row << attendance_symbol(att_map[s.id]&.status, syms) }
        row += summary_values(reg, sessions)
        csv << row
        extra_empty_rows.to_i.times { csv << [] }
      end
    end
  end

  # ── Anwesenheitsliste: XLSX ──────────────────────────────────────────────────

  def generate_attendance_xlsx(course, date_range)
    require "caxlsx"

    sessions      = sessions_for_course(course, date_range)
    registrations = sorted_registrations(course)
    syms          = effective_symbols

    package = Axlsx::Package.new
    wb      = package.workbook

    wb.add_worksheet(name: (course&.title || "Anwesenheit").first(31)) do |sheet|
      st = sheet.styles
      hdr      = st.add_style(b: true, bg_color: "1F2937", fg_color: "FFFFFF",
                               alignment: { horizontal: :center, wrap_text: true })
      s_present = st.add_style(bg_color: "D1FAE5", fg_color: "065F46",
                                alignment: { horizontal: :center })
      s_absent  = st.add_style(bg_color: "FEE2E2", fg_color: "991B1B",
                                alignment: { horizontal: :center })
      s_excused = st.add_style(bg_color: "FEF3C7", fg_color: "92400E",
                                alignment: { horizontal: :center })
      s_none    = st.add_style(fg_color: "9CA3AF", alignment: { horizontal: :center })
      s_summary = st.add_style(b: true, bg_color: "F3F4F6",
                                alignment: { horizontal: :center })

      if include_header?
        hdrs = fixed_column_headers + sessions.map { |s| format_session_date(s) } + summary_column_headers
        sheet.add_row hdrs, style: hdr
      end

      registrations.each do |reg|
        att_map    = reg.attendances.index_by(&:training_session_id)
        row_data   = fixed_column_values(reg.participant)
        row_styles = Array.new(row_data.size, nil)

        sessions.each do |s|
          status = att_map[s.id]&.status
          row_data << attendance_symbol(status, syms)
          row_styles << case status
                        when "anwesend"   then s_present
                        when "abwesend"   then s_absent
                        when "abgemeldet" then s_excused
                        else s_none
                        end
        end

        sv = summary_values(reg, sessions)
        row_data   += sv
        row_styles += Array.new(sv.size, s_summary)

        sheet.add_row row_data, style: row_styles
        extra_empty_rows.to_i.times { sheet.add_row [] }
      end

      # Auto-Filter auf Kopfzeile
      if include_header? && registrations.any?
        last_col = (fixed_column_headers.size + sessions.size + summary_column_headers.size - 1)
        sheet.auto_filter = "A1:#{col_letter(last_col)}1"
      end
    end

    package.to_stream.read
  end

  # ── Anwesenheitsliste: PDF ───────────────────────────────────────────────────

  def generate_attendance_pdf(course, date_range)
    require "prawn"
    require "prawn/table"

    sessions      = sessions_for_course(course, date_range)
    registrations = sorted_registrations(course)
    syms          = effective_symbols

    pdf = Prawn::Document.new(
      page_layout: :landscape,
      page_size:   "A4",
      margin:      [ 25, 25, 25, 25 ]
    )

    # Titel
    pdf.font_size(13) { pdf.text course&.title || "Anwesenheitsliste", style: :bold }
    range = effective_date_range
    pdf.text "#{range.first.strftime('%d.%m.%Y')} – #{range.last.strftime('%d.%m.%Y')}",
             size: 9, color: "6B7280"
    pdf.move_down 8

    table_data = []

    if include_header?
      table_data << fixed_column_headers + sessions.map { |s| format_session_date(s) } + summary_column_headers
    end

    registrations.each do |reg|
      att_map = reg.attendances.index_by(&:training_session_id)
      row = fixed_column_values(reg.participant)
      sessions.each { |s| row << attendance_symbol(att_map[s.id]&.status, syms) }
      row += summary_values(reg, sessions)
      table_data << row
      extra_empty_rows.to_i.times { table_data << Array.new((table_data.first&.size || 1), "") }
    end

    if table_data.size > (include_header? ? 1 : 0)
      fixed_w   = [ 55 ] * fixed_column_headers.size
      avail_w   = pdf.bounds.width - fixed_w.sum - summary_column_headers.size * 35
      session_w = sessions.any? ? [ [ avail_w / sessions.size, 18 ].max, 45 ].min : 0
      summary_w = Array.new(summary_column_headers.size, 35)
      col_widths = fixed_w + Array.new(sessions.size, session_w) + summary_w

      pdf.table(table_data, width: pdf.bounds.width, column_widths: col_widths) do |t|
        t.cells.size    = 7
        t.cells.padding = [ 3, 4 ]
        t.cells.border_width = 0.5

        if include_header?
          t.row(0).font_style       = :bold
          t.row(0).background_color = "1F2937"
          t.row(0).text_color       = "FFFFFF"
          t.row(0).size             = 7
        end

        # Farbige Zellen für Anwesenheitsstatus
        start_col = fixed_column_headers.size
        registrations.each_with_index do |reg, row_idx|
          data_row = include_header? ? row_idx + 1 : row_idx
          att_map  = reg.attendances.index_by(&:training_session_id)
          sessions.each_with_index do |s, col_idx|
            status = att_map[s.id]&.status
            col    = start_col + col_idx
            cell   = t.rows(data_row).columns(col)
            case status
            when "anwesend"   then cell.background_color = "D1FAE5"
            when "abwesend"   then cell.background_color = "FEE2E2"
            when "abgemeldet" then cell.background_color = "FEF3C7"
            end
          end
        end
      end
    else
      pdf.text "Keine Daten vorhanden.", color: "9CA3AF"
    end

    pdf.render
  end

  # ── BASPO Personenimport CSV ────────────────────────────────────────────────

  BASPO_HEADERS = %w[
    PERSONENNUMMER NAME VORNAME GEBURTSDATUM GESCHLECHT AHV_NR PEID
    NATIONALITAET MUTTERSPRACHE STRASSE HAUSNUMMER PLZ ORT LAND
  ].freeze

  GENDER_MAP = { "männlich" => "m", "weiblich" => "w" }.freeze

  def generate_baspo_person_csv(participants)
    bom = "\xEF\xBB\xBF"
    csv = CSV.generate(col_sep: ";", row_sep: "\r\n", headers: BASPO_HEADERS, write_headers: true) do |csv|
      participants.each do |p|
        csv << [
          p.js_person_number,
          p.last_name,
          p.first_name,
          p.date_of_birth&.strftime("%d.%m.%Y"),
          GENDER_MAP[p.gender] || p.gender,
          p.ahv_number,
          nil,
          p.nationality,
          p.mother_tongue,
          p.street,
          p.house_number,
          p.zip_code,
          p.city,
          p.country
        ]
      end
    end
    bom + csv
  end

  # ── Zentrale Dispatch-Methode ────────────────────────────────────────────────

  def generate_export(participants_or_course, date_range = nil)
    if export_type == "anwesenheitsliste"
      dr = date_range || effective_date_range
      case format
      when "xlsx" then generate_attendance_xlsx(participants_or_course, dr)
      when "pdf"  then generate_attendance_pdf(participants_or_course, dr)
      else             generate_attendance_csv(participants_or_course, dr)
      end
    elsif export_type == "baspo_personenimport"
      generate_baspo_person_csv(participants_or_course)
    else
      generate_csv(participants_or_course)
    end
  end

  # ── Private Hilfsmethoden ────────────────────────────────────────────────────

  private

  def at_least_one_field
    errors.add(:fields, "mindestens ein Feld muss ausgewählt sein") if fields.reject(&:blank?).empty?
  end

  def sessions_for_course(course, date_range)
    return [] unless course
    scope = course.training_sessions
                  .where(start_time: date_range.first.beginning_of_day..date_range.last.end_of_day)
                  .order(:start_time)
    scope = scope.where(is_canceled: [ false, nil ]) unless include_canceled_sessions?
    scope.includes(:attendances).to_a
  end

  def sorted_registrations(course)
    return [] unless course
    regs = course.course_registrations
                 .where(status: "bestätigt")
                 .includes(participant: :user, attendances: [])
                 .to_a
    case sort_by
    when "first_name"
      regs.sort_by { |r| r.participant.first_name.to_s.downcase }
    when "attendance_rate"
      regs.sort_by do |r|
        atts    = r.attendances.reject { |a| a.status.nil? || a.status == "abgemeldet" }
        present = atts.count { |a| a.status == "anwesend" }
        atts.empty? ? -1.0 : -(present.to_f / atts.size)
      end
    else
      regs.sort_by { |r| r.participant.last_name.to_s.downcase }
    end
  end

  def fixed_column_headers
    fields.reject(&:blank?).map { |f| AVAILABLE_FIELDS[f] || f }
  end

  def fixed_column_values(participant)
    fields.reject(&:blank?).map do |field|
      case field
      when "last_name"     then participant.last_name
      when "first_name"    then participant.first_name
      when "date_of_birth" then participant.date_of_birth&.strftime("%d.%m.%Y")
      when "phone_number"  then participant.phone_number
      when "gender"        then participant.gender
      when "ahv_number"    then participant.ahv_number
      when "user_email"    then participant.user.email
      when "courses"       then participant.courses.map(&:title).join(", ")
      end
    end
  end

  def attendance_headers(sessions)
    fixed_column_headers + sessions.map { |s| format_session_date(s) } + summary_column_headers
  end

  def format_session_date(session)
    return "" unless session.start_time
    case date_column_format
    when "%d.%m."
      session.start_time.strftime("%d.%m.")
    when "kw"
      wday = I18n.l(session.start_time, format: "%A") rescue session.start_time.strftime("%A")
      "KW#{session.start_time.strftime('%V')} #{wday}"
    else
      session.start_time.strftime("%d.%m.%Y")
    end
  end

  def effective_symbols
    ATTENDANCE_SYMBOL_PRESETS[attendance_symbols] || ATTENDANCE_SYMBOL_PRESETS["symbols"]
  end

  def attendance_symbol(status, syms = nil)
    syms ||= effective_symbols
    case status
    when "anwesend"   then syms["anwesend"]
    when "abwesend"   then syms["abwesend"]
    when "abgemeldet" then syms["abgemeldet"]
    else                   syms["keine"]
    end
  end

  def summary_column_headers
    return [] if include_summary_columns.blank?
    include_summary_columns.reject(&:blank?).map { |c| SUMMARY_COLUMNS[c] || c }
  end

  def summary_values(registration, sessions)
    return [] if include_summary_columns.blank?
    att_map       = registration.attendances.index_by(&:training_session_id)
    non_canceled  = sessions.reject(&:is_canceled?)

    include_summary_columns.reject(&:blank?).map do |col|
      case col
      when "present_count"
        non_canceled.count { |s| att_map[s.id]&.status == "anwesend" }
      when "absent_count"
        non_canceled.count { |s| att_map[s.id]&.status == "abwesend" }
      when "excused_count"
        non_canceled.count { |s| att_map[s.id]&.status == "abgemeldet" }
      when "attendance_rate"
        recorded = non_canceled.count { |s| %w[anwesend abwesend].include?(att_map[s.id]&.status) }
        present  = non_canceled.count { |s| att_map[s.id]&.status == "anwesend" }
        recorded > 0 ? "#{(present * 100.0 / recorded).round(1)}%" : "—"
      end
    end
  end

  def col_letter(index)
    result = ""
    index += 1
    while index > 0
      index, rem = (index - 1).divmod(26)
      result = (65 + rem).chr + result
    end
    result
  end
end
