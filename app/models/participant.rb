class Participant < ApplicationRecord
  belongs_to :user

  has_many :course_registrations, dependent: :destroy
  has_many :courses, through: :course_registrations

  GENDERS = %w[männlich weiblich].freeze
  NATIONALITIES = %w[CH FL Andere].freeze
  MOTHER_TONGUES = %w[DE FR IT Andere].freeze
  COUNTRIES = %w[
    AF AX AL DZ AS AD AO AI AQ AG AR AM AW AU AT AZ BS BH BD BB BY BE BZ BJ BM BT BO BQ BA BW BV BR
    IO BN BG BF BI CV KH CM CA KY CF TD CL CX CC CO KM CD CG CK CR HR CU CW CY CZ DK DJ DM DO EC EG
    SV GQ ER EE SZ ET FK FO FJ FI FR GF PF TF GA GM GE DE GH GI GR GL GD GP GU GT GG GN GW GY HT HM
    VA HN HK HU IS IN ID IR IQ IE IM IL IT JM JP JE JO KZ KE KI KP KR KW KG LA LV LB LS LR LY LI LT
    LU MO MG MW MY MV ML MT MH MQ MR MU YT MX FM MD MC MN ME MS MA MZ MM NA NR NP NL NC NZ NI NE NG
    NU NF MK MP NO OM PK PW PS PA PG PY PE PH PN PL PT PR QA RE RO RU RW BL SH KN LC MF PM VC WS SM
    ST SA SN RS SC SL SG SX SK SI SB SO ZA GS SS ES LK SD SR SJ SZ SE CH SY TW TJ TZ TH TL TG TK TO
    TT TN TR TM TC TV UG UA AE GB US UM UY UZ VU VE VN VG VI WF EH YE ZM ZW
  ].freeze

  validates :first_name, :last_name, :date_of_birth, :gender, :phone_number, presence: true
  validates :gender, inclusion: { in: GENDERS }
  validates :first_name, uniqueness: {
    scope: [ :last_name, :date_of_birth, :user_id ],
    message: "– diese Person ist in deinem Profil bereits erfasst"
  }

  # AHV-Nummer: 756.XXXX.XXXX.XX
  validates :ahv_number,
            format: {
              with: /\A756\.\d{4}\.\d{4}\.\d{2}\z/,
              message: "muss im Format 756.XXXX.XXXX.XX angegeben werden"
            },
            allow_blank: true
  validate :ahv_required_for_minors, if: -> { date_of_birth.present? }
  validate :ahv_number_cannot_be_cleared, on: :update

  validate :phone_number_format, if: -> { phone_number.present? }
  validate :date_of_birth_plausible, if: -> { date_of_birth.present? }

  # Hausnummer: Zahl mit optionalem Buchstaben (z.B. 12 oder 12a)
  validates :house_number,
            format: {
              with: /\A\d+[a-zA-Z]?\z/,
              message: "muss mit einer Zahl beginnen (z.B. 12 oder 12a)"
            },
            allow_blank: true

  # PLZ: 4–6 Ziffern
  validates :zip_code,
            format: {
              with: /\A\d{4,6}\z/,
              message: "muss aus 4–6 Ziffern bestehen"
            },
            allow_blank: true

  # J+S Personennummer: genau 9 Ziffern
  validates :js_person_number,
            format: {
              with: /\A\d{9}\z/,
              message: "muss genau 9 Ziffern enthalten"
            },
            allow_blank: true

  def has_trialed_in_category?(category)
    sibling_ids = trial_sibling_ids
    CourseRegistration
      .joins(:course)
      .where(participant_id: sibling_ids)
      .where(status: "schnuppern")
      .where(courses: { category: category })
      .where(
        "(course_registrations.trial_expires_at IS NOT NULL AND course_registrations.trial_expires_at > :now) OR " \
        "(course_registrations.trial_expires_at IS NULL AND course_registrations.created_at > :cutoff)",
        now: Time.current, cutoff: 7.days.ago
      )
      .exists?
  end

  def ever_trialed_in_category?(category)
    sibling_ids = trial_sibling_ids
    CourseRegistration
      .joins(:course)
      .where(participant_id: sibling_ids)
      .where(status: "schnuppern")
      .where(courses: { category: category })
      .exists?
  end

  def ever_registered_in_category?(category)
    sibling_ids = trial_sibling_ids
    CourseRegistration
      .joins(:course)
      .where(participant_id: sibling_ids)
      .where(courses: { category: category })
      .where.not(status: %w[schnuppern ausstehend])
      # Eine stornierte Anmeldung blockiert nur, wenn sie eine echte (bezahlte/
      # bestätigte) Anmeldung war. Ein storniertes Schnuppertraining (erkennbar an
      # gesetztem trial_expires_at) darf erneutes Schnuppern nicht verhindern.
      .where.not("course_registrations.status = ? AND course_registrations.trial_expires_at IS NOT NULL", "storniert")
      .exists?
  end

  def schnupper_eligible_for_category?(category)
    return false if ever_trialed_in_category?(category)
    return false if ever_registered_in_category?(category)

    sibling_ids = trial_sibling_ids
    CourseRegistration
      .joins(:course)
      .where(participant_id: sibling_ids)
      .where(courses: { category: category })
      .where.not(status: %w[storniert ausstehend])
      .none?
  end

  # AHV-Nummer ist für Kinder/Jugendliche Pflicht.
  # Optional nur für Erwachsene, die bei Kursstart älter als 20 Jahre sind.
  def ahv_required_for?(course)
    age = age_at(course.age_reference_date)
    age.nil? || age <= 20
  end

  # Gibt fehlende Pflichtfelder für einen bestimmten Kurs zurück (als Symbole)
  def missing_fields_for(course)
    fields = course.required_participant_fields
    fields |= [ :ahv_number ] if ahv_required_for?(course)
    fields.select { |field| self[field].blank? }
  end

  def minor?
    date_of_birth.present? && age_at(Date.today) < 18
  end

  # Alter am Referenzdatum (z.B. Kursstart). Gibt nil zurück, wenn kein Geburtsdatum vorhanden.
  def age_at(reference_date)
    return nil unless date_of_birth
    ref = reference_date.to_date
    age = ref.year - date_of_birth.year
    had_birthday = (ref.month > date_of_birth.month) ||
                   (ref.month == date_of_birth.month && ref.day >= date_of_birth.day)
    had_birthday ? age : age - 1
  end

  # Human-readable Label für ein Pflichtfeld
  def self.field_label(field)
    Course::CONFIGURABLE_REQUIRED_FIELDS[field] || field.to_s.humanize
  end

  # IDs aller Participants mit derselben Identität (kontoübergreifend):
  # AHV-Nummer falls vorhanden, sonst Vorname + Nachname + Geburtsdatum.
  # Genutzt für Schnupper-Prüfungen und Rabatt-Ermittlung (DiscountCalculator).
  def identity_sibling_ids
    if ahv_number.present?
      normalized = ahv_number.gsub(/[\s.]/, "")
      Participant
        .where("REPLACE(REPLACE(ahv_number, '.', ''), ' ', '') = ?", normalized)
        .pluck(:id)
    else
      Participant
        .where("LOWER(TRIM(first_name)) = ? AND LOWER(TRIM(last_name)) = ? AND date_of_birth = ?",
               first_name.to_s.strip.downcase, last_name.to_s.strip.downcase, date_of_birth)
        .pluck(:id)
    end
  end

  private

  def phone_number_format
    # Nur die Ziffern zählen. Trenner wie Leerzeichen (auch geschützte/Unicode),
    # Bindestriche, Klammern, Punkte oder Schrägstriche werden ignoriert, damit
    # gültige Nummern wie "+41 78 911 29 00" nicht fälschlich abgelehnt werden.
    unless phone_number.count("0-9") >= 7
      errors.add(:phone_number, "muss mindestens 7 Ziffern haben (erlaubt: +, Ziffern, Leerzeichen, -)")
    end
  end

  def ahv_required_for_minors
    errors.add(:ahv_number, "ist für Personen unter 18 Jahren Pflicht") if minor? && ahv_number.blank?
  end

  def ahv_number_cannot_be_cleared
    return unless ahv_number_was.present? && ahv_number.blank?
    errors.add(:ahv_number, "kann nicht gelöscht werden")
  end

  def date_of_birth_plausible
    if date_of_birth >= Date.today
      errors.add(:date_of_birth, "muss in der Vergangenheit liegen")
    elsif date_of_birth < 120.years.ago.to_date
      errors.add(:date_of_birth, "ist nicht plausibel (mehr als 120 Jahre zurück)")
    end
  end

  def trial_sibling_ids
    identity_sibling_ids
  end
end
