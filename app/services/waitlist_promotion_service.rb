# Kapselt die Hochstufungs-Logik, wenn ein bestätigter Platz frei wird.
# Genutzt von CourseRegistrationsController nach cancel, trainer_cancel und destroy.
class WaitlistPromotionService
  MAX_PROMOTIONS_PER_CALL = 10

  # Stuft Wartelisten-Anmeldungen hoch, bis der Kurs wieder voll ist oder
  # keine Wartelisten-Einträge mehr vorhanden sind (max. MAX_PROMOTIONS_PER_CALL).
  #
  # training_session_id: nil  → Semester-Modus (warteliste ohne Session-Bezug)
  # training_session_id: X    → Single-Session-Modus (nur dieser Termin)
  #
  # Pessimistischer Lock auf den Kurs-Datensatz: verhindert, dass zwei gleichzeitige
  # Stornierungen (z.B. Trainer + Elternteil im selben Moment) dieselbe Wartelisten-
  # Anmeldung doppelt hochstufen, weil beide das gleiche confirmed_count lesen.
  def self.promote_next_from_waitlist(course, training_session_id: nil)
    promoted = []

    course.with_lock do
      return unless course.enable_waitlist?
      return if course.max_participants.blank?

      paid_course = course.has_payment? && course.price_cents.to_i > 0
      occupied_statuses = paid_course ? %w[bestätigt ausstehend schnuppern] : %w[bestätigt schnuppern]

      confirmed_scope = course.course_registrations.where(status: occupied_statuses)
      waitlist_scope  = course.course_registrations.where(status: "warteliste")

      if training_session_id.present?
        confirmed_scope = confirmed_scope.where(training_session_id: training_session_id)
        waitlist_scope  = waitlist_scope.where(training_session_id: training_session_id)
      else
        confirmed_scope = confirmed_scope.where(training_session_id: nil)
        waitlist_scope  = waitlist_scope.where(training_session_id: nil)
      end

      new_status = paid_course ? "ausstehend" : "bestätigt"

      MAX_PROMOTIONS_PER_CALL.times do
        break if confirmed_scope.distinct.count(:participant_id) >= course.max_participants

        next_in_line = waitlist_scope.order(:created_at).first
        break unless next_in_line

        update_attrs = { status: new_status }
        next_in_line.update!(update_attrs)
        promoted << next_in_line
      end
    end

    promoted.each { |reg| CourseRegistrationMailer.waitlist_promoted(reg).deliver_later }
  end
end
