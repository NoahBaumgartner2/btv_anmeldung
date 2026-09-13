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
#
# Kurse OHNE Zeitraum ("Eigener Zeitraum", laufend, z.B. Krabbelgym) haben
# keinen Term und tauchen daher in .for(term) NIE auf, unabhängig vom
# gewählten Zeitraum - sie laufen aber unbegrenzt weiter und können trotzdem
# jederzeit jemanden enthalten, der/die inzwischen zu alt geworden ist. Dafür
# gibt es .termless: prüft diese Kurse unabhängig von jedem Term, mit HEUTE
# als Stichtag (es gibt keinen "neuen Kurs", in den man hineinwächst - nur
# die Frage, ob die Person JETZT noch ins Alterslimit passt).
class AgeTransitionReport
  Entry = Struct.new(:participant, :age_at_reference, :already_too_old, :exemption, keyword_init: true) do
    def exempt? = exemption.present?
  end

  Group = Struct.new(:course, :previous_course, :entries, :continuous, keyword_init: true) do
    def continuous? = continuous == true
  end

  def self.for(term)
    new(term: term).call
  end

  def self.termless
    new(reference_date: Date.current).call
  end

  def initialize(term: nil, reference_date: nil)
    @term = term
    @reference_date_override = reference_date
  end

  def call
    return [] if @term.blank? && @reference_date_override.blank?

    scope = @reference_date_override ? Course.where(term_id: nil) : Course.where(term_id: @term.id)
    scope.where.not(max_age: nil)
         .includes(:previous_course, :age_exemptions)
         .order(title: :asc)
         .filter_map { |course| build_group(course) }
  end

  private

  def build_group(course)
    continuous = @reference_date_override.present?
    source = continuous ? course : (course.previous_course || course)
    reference_date = @reference_date_override || course.age_reference_date
    exemptions_by_participant_id = course.age_exemptions.index_by(&:participant_id)

    entries = active_participants(source).filter_map do |participant|
      age = participant.age_at(reference_date)
      next if age.blank? || age <= course.max_age

      Entry.new(
        participant:      participant,
        age_at_reference: age,
        already_too_old:  continuous ? true : too_old_for?(source, participant),
        exemption:        exemptions_by_participant_id[participant.id]
      )
    end
    return nil if entries.empty?

    Group.new(
      course:          course,
      previous_course: continuous ? nil : course.previous_course,
      continuous:      continuous,
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
