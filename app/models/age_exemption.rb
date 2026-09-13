# Altersausnahme: erlaubt einer konkreten Person die Anmeldung in einem
# konkreten Kurs, obwohl sie dessen Höchstalter überschreitet. Gedacht für den
# Perioden-Übergang (Quartal/Semester): wer aus dem Vorgängerkurs herauswächst,
# darf per Ausnahme trotzdem im Vorrang-Fenster weitermachen.
#
# Greift ausschliesslich in Course#registration_blocked_by_age? - die reine
# Altersauskunft (Course#accepts_participant_age?) bleibt davon unberührt,
# damit Auswertungen/Anzeigen weiterhin das tatsächliche Alter widerspiegeln.
class AgeExemption < ApplicationRecord
  belongs_to :participant
  belongs_to :course
  belongs_to :granted_by, class_name: "User", optional: true

  validates :participant_id, uniqueness: { scope: :course_id }
end
