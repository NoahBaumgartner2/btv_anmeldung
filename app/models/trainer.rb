class Trainer < ApplicationRecord
  belongs_to :user

  has_many :course_trainers, dependent: :destroy
  has_many :courses, through: :course_trainers

  GENDERS = %w[männlich weiblich].freeze

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

  def full_name
    [first_name, last_name].compact.join(" ").presence || user.email
  end
end
