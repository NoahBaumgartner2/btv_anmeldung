class Attendance < ApplicationRecord
  belongs_to :training_session
  belongs_to :course_registration

  STATUSES = %w[anwesend abwesend abgemeldet].freeze

  validates :status, inclusion: { in: STATUSES }, allow_nil: true

  def abgemeldet?
    status == "abgemeldet"
  end
end
