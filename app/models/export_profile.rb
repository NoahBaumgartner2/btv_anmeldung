require "csv"

class ExportProfile < ApplicationRecord
  belongs_to :course, optional: true

  SCHEDULES = {
    "none"    => "Kein automatischer Export",
    "daily"   => "Täglich",
    "weekly"  => "Wöchentlich",
    "monthly" => "Monatlich"
  }.freeze

  COL_SEPS = {
    ";"  => 'Semikolon  ;',
    ","  => 'Komma  ,',
    "\t" => 'Tabulator  ⇥',
    "|"  => 'Pipe  |'
  }.freeze

  ROW_SEPS = {
    "\\n"   => 'LF  \n  (Unix/Mac)',
    "\\r\\n" => 'CRLF  \r\n  (Windows/Excel)'
  }.freeze

  QUOTE_CHARS = {
    '"'  => 'Anführungszeichen  "',
    "'"  => "Apostroph  '",
    ""   => "Keines"
  }.freeze

  AVAILABLE_FIELDS = {
    "last_name"     => "Nachname",
    "first_name"    => "Vorname",
    "date_of_birth" => "Geburtsdatum",
    "user_email"    => "E-Mail",
    "phone_number"  => "Telefon",
    "gender"        => "Geschlecht",
    "ahv_number"    => "AHV-Nummer",
    "courses"       => "Eingeschriebene Kurse"
  }.freeze

  validates :name,     presence: true
  validates :format,   inclusion: { in: %w[csv] }
  validates :schedule, inclusion: { in: SCHEDULES.keys }
  validates :col_sep,  inclusion: { in: COL_SEPS.keys }
  validates :row_sep,  inclusion: { in: ROW_SEPS.keys }
  validate  :at_least_one_field
  validates :recipient_email,
            format: { with: URI::MailTo::EMAIL_REGEXP },
            allow_blank: true
  validates :recipient_email,
            presence: { message: "wird benötigt wenn ein Intervall gewählt ist" },
            if: -> { schedule != "none" }

  # ── Effektive Trennzeichen für CSV-Gem ─────────────────────────────────────
  def effective_col_sep
    col_sep.presence || ";"
  end

  def effective_row_sep
    case row_sep
    when "\\r\\n" then "\r\n"
    else               "\n"
    end
  end

  def effective_quote_char
    # CSV-Gem braucht ein einzelnes Zeichen; leerer String = kein Quoting
    quote_char.presence || '"'
  end

  # ── CSV generieren ──────────────────────────────────────────────────────────
  def generate_csv(participants)
    opts = {
      col_sep:    effective_col_sep,
      row_sep:    effective_row_sep,
      quote_char: effective_quote_char,
      headers:    include_header? ? csv_headers : false,
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

  private

  def at_least_one_field
    errors.add(:fields, "mindestens ein Feld muss ausgewählt sein") if fields.reject(&:blank?).empty?
  end
end
