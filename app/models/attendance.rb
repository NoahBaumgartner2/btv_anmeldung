class Attendance < ApplicationRecord
  belongs_to :training_session
  belongs_to :course_registration
  # Gesetzt, wenn diese Abmeldung automatisch einen Abo-Ausgleichseintritt ausgelöst
  # hat (siehe Course#grant_abo_makeup_entry!). Wird beim Wieder-Anmelden gebraucht,
  # um den Eintritt zurückzunehmen bzw. die Anmeldung zu blockieren, falls er
  # inzwischen bereits verbraucht wurde (siehe #resubscribe_to_session).
  belongs_to :abo_makeup_registration, class_name: "CourseRegistration", optional: true

  STATUSES = %w[anwesend abwesend abgemeldet].freeze

  validates :status, inclusion: { in: STATUSES }, allow_nil: true

  def abgemeldet?
    status == "abgemeldet"
  end
end
