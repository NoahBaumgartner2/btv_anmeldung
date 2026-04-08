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
    scope: [:last_name, :date_of_birth, :user_id],
    message: "– diese Person ist in deinem Profil bereits erfasst"
  }

  # Gibt fehlende Pflichtfelder für einen bestimmten Kurs zurück (als Symbole)
  def missing_fields_for(course)
    course.required_participant_fields.select { |field| self[field].blank? }
  end

  # Human-readable Label für ein Pflichtfeld
  def self.field_label(field)
    Course::CONFIGURABLE_REQUIRED_FIELDS[field] || field.to_s.humanize
  end
end
