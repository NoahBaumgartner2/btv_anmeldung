# Übersicht pro Zeitraum (Term): wer überschreitet in den Kursen dieses
# Zeitraums das Höchstalter?
#
# Für Kurse MIT Vorgängerkurs (Rollover-Nachfolger) wird bewusst der
# Teilnehmerbestand des VORGÄNGERS geprüft - das sind die Personen, die sich im
# Vorrang-Fenster neu anmelden würden, und genau dort entscheidet sich, wer
# herauswächst. Für Kurse OHNE Vorgänger wird der eigene Bestand geprüft.
#
# Unterschieden wird:
#   already_too_old = true  -> war schon im Ausgangskurs über dem Höchstalter
#   already_too_old = false -> wird erst im neuen Kurs zu alt
#
# Kurse ohne Höchstalter bleiben aussen vor - dort wächst niemand heraus.
class AgeTransitionReport
  Entry = Struct.new(:participant, :age_at_reference, :already_too_old, :exemption, keyword_init: true) do
    def exempt? = exemption.present?
  end

  Group = Struct.new(:course, :previous_course, :entries, keyword_init: true)

  def self.for(term)
    new(term).call
  end

  def initialize(term)
    @term = term
  end

  def call
    return [] if @term.blank?

    Course.where(term_id: @term.id)
          .where.not(max_age: nil)
          .includes(:previous_course, :age_exemptions)
          .order(title: :asc)
          .filter_map { |course| build_group(course) }
  end

  private

  def build_group(course)
    source = course.previous_course || course
    exemptions_by_participant_id = course.age_exemptions.index_by(&:participant_id)

    entries = active_participants(source).filter_map do |participant|
      age = participant.age_at(course.age_reference_date)
      next if age.blank? || age <= course.max_age

      Entry.new(
        participant:      participant,
        age_at_reference: age,
        already_too_old:  too_old_for?(source, participant),
        exemption:        exemptions_by_participant_id[participant.id]
      )
    end
    return nil if entries.empty?

    Group.new(
      course:          course,
      previous_course: course.previous_course,
      entries:         entries.sort_by { |e| [ e.participant.last_name.to_s, e.participant.first_name.to_s ] }
    )
  end

  def too_old_for?(course, participant)
    return false if course.max_age.blank?
    age = participant.age_at(course.age_reference_date)
    age.present? && age > course.max_age
  end

  def active_participants(course)
    Participant.where(
      id: course.course_registrations.where.not(status: "storniert").select(:participant_id)
    ).to_a
  end
end
