# Kapselt die Hochstufungs-Logik, wenn ein bestätigter Platz frei wird.
# Genutzt von CourseRegistrationsController nach cancel, trainer_cancel und destroy.
class WaitlistPromotionService
  # Stuft die älteste Wartelisten-Anmeldung im betroffenen Slot hoch.
  #
  # training_session_id: nil  → Semester-Modus (warteliste ohne Session-Bezug)
  # training_session_id: X    → Single-Session-Modus (nur dieser Termin)
  #
  # Pessimistischer Lock auf den Kurs-Datensatz: verhindert, dass zwei gleichzeitige
  # Stornierungen (z.B. Trainer + Elternteil im selben Moment) dieselbe Wartelisten-
  # Anmeldung doppelt hochstufen, weil beide das gleiche confirmed_count lesen.
  def self.promote_next_from_waitlist(course, training_session_id: nil)
    course.with_lock do
      return if course.max_participants.blank?

      paid_course = course.has_payment? && course.price_cents.to_i > 0

      # Bei kostenpflichtigen Kursen belegen "ausstehend"-Anmeldungen den Platz bereits –
      # sie werden erst durch mark_paid! auf "bestätigt" gesetzt. Ohne diese Statuses
      # würde der Service mehrere Wartelisten-Personen hochstufen, obwohl der Platz
      # durch noch nicht bezahlte Anmeldungen schon vergeben ist.
      occupied_statuses = paid_course ? %w[bestätigt ausstehend] : %w[bestätigt]

      confirmed_scope = course.course_registrations.where(status: occupied_statuses)
      waitlist_scope  = course.course_registrations.where(status: "warteliste")

      if training_session_id.present?
        confirmed_scope = confirmed_scope.where(training_session_id: training_session_id)
        waitlist_scope  = waitlist_scope.where(training_session_id: training_session_id)
      else
        confirmed_scope = confirmed_scope.where(training_session_id: nil)
        waitlist_scope  = waitlist_scope.where(training_session_id: nil)
      end

      return if confirmed_scope.count >= course.max_participants

      next_in_line = waitlist_scope.order(:created_at).first
      return unless next_in_line

      new_status = paid_course ? "ausstehend" : "bestätigt"
      next_in_line.update!(status: new_status)
      CourseRegistrationMailer.waitlist_promoted(next_in_line).deliver_later
    end
  end
end
