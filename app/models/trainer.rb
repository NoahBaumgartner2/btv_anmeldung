class Trainer < ApplicationRecord
  belongs_to :user

  has_many :course_trainers, dependent: :destroy
  has_many :courses, through: :course_trainers

  has_many :cancelled_registrations,
           class_name: "CourseRegistration",
           foreign_key: :cancelled_by_trainer_id,
           dependent: :nullify,
           inverse_of: :cancelled_by_trainer

  GENDERS = %w[männlich weiblich].freeze

  REQUIRED_PROFILE_FIELDS = %i[
    first_name last_name phone date_of_birth gender ahv_number
    street house_number zip_code city country nationality mother_tongue
  ].freeze

  validates(*REQUIRED_PROFILE_FIELDS, presence: true, on: :profile_completion)

  validate :phone_format, if: -> { phone.present? }
  validate :date_of_birth_plausible, if: -> { date_of_birth.present? }

  validates :ahv_number,
            format: { with: /\A756\.\d{4}\.\d{4}\.\d{2}\z/,
                      message: "muss im Format 756.XXXX.XXXX.XX angegeben werden" },
            allow_blank: true

  validates :zip_code,
            format: { with: /\A\d{4,6}\z/, message: "muss aus 4–6 Ziffern bestehen" },
            allow_blank: true

  validates :js_person_number,
            format: { with: /\A\d{9}\z/, message: "muss genau 9 Ziffern enthalten" },
            allow_blank: true

  validates :iban,
            format: { with: /\ACH\d{2}[0-9A-Z\s]{15,}\z/i,
                      message: "muss mit CH beginnen (Format: CH56 0483 5012 3456 7800 9)" },
            allow_blank: true

  # Ein Eltern-Account (mit angemeldeten Kindern) darf nicht zugleich Trainer sein.
  # Nur auf :create – bestehende Trainer bleiben editierbar.
  validate :user_must_not_have_participants, on: :create

  def full_name
    [ first_name, last_name ].compact.join(" ").presence || user.email
  end

  def profile_complete?
    REQUIRED_PROFILE_FIELDS.all? { |f| public_send(f).present? }
  end

  private

  def phone_format
    # Nur die Ziffern zählen. Trenner wie Leerzeichen (auch geschützte/Unicode),
    # Bindestriche, Klammern, Punkte oder Schrägstriche werden ignoriert, damit
    # gültige Nummern wie "+41 78 911 29 00" nicht fälschlich abgelehnt werden.
    unless phone.count("0-9") >= 7
      errors.add(:phone, "muss mindestens 7 Ziffern haben (erlaubt: +, Ziffern, Leerzeichen, -)")
    end
  end

  def date_of_birth_plausible
    if date_of_birth >= Date.today
      errors.add(:date_of_birth, "muss in der Vergangenheit liegen")
    elsif date_of_birth < 120.years.ago.to_date
      errors.add(:date_of_birth, "ist nicht plausibel (mehr als 120 Jahre zurück)")
    end
  end

  def user_must_not_have_participants
    return if user.blank?

    if user.participants.exists?
      errors.add(:base, "Dieser Account ist ein Eltern-Account mit angemeldeten Kindern " \
                        "und kann nicht zugleich als Trainer erfasst werden. Bitte ein separates " \
                        "Konto mit einer anderen E-Mail-Adresse verwenden.")
    end
  end
end
