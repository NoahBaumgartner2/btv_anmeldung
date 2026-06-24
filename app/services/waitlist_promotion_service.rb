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
      # "platz_frei" hält einen reservierten Platz (Entscheidung Schnuppern/Anmelden offen)
      # und zählt daher immer als belegt, sonst würde derselbe Platz doppelt vergeben.
      occupied_statuses = paid_course ? %w[bestätigt ausstehend schnuppern platz_frei] : %w[bestätigt schnuppern platz_frei]

      confirmed_scope = course.course_registrations.where(status: occupied_statuses)
      waitlist_scope  = course.course_registrations.where(status: "warteliste")

      if training_session_id.present?
        confirmed_scope = confirmed_scope.where(training_session_id: training_session_id)
        waitlist_scope  = waitlist_scope.where(training_session_id: training_session_id)
      else
        confirmed_scope = confirmed_scope.where(training_session_id: nil)
        waitlist_scope  = waitlist_scope.where(training_session_id: nil)
      end

      MAX_PROMOTIONS_PER_CALL.times do
        break if confirmed_scope.distinct.count(:participant_id) >= course.max_participants

        next_in_line = waitlist_scope.order(:created_at).first
        break unless next_in_line

        # Darf der Teilnehmer in dieser Kategorie noch schnuppern (hat seine einmalige
        # Schnuppermöglichkeit noch nicht genutzt)? Dann bekommt er den Platz "auf Probe":
        # Status "platz_frei" mit 7-Tage-Frist, und entscheidet selbst zwischen Schnuppern
        # und regulärer Anmeldung (siehe CourseRegistrations#accept_spot). Hinweis: bewusst
        # ever_trialed_in_category? (nicht schnupper_eligible_for_category?), da die eigene
        # Wartelisten-Anmeldung sich sonst selbst als "bereits registriert" blockieren würde.
        eligible_to_choose = course.allows_trial? &&
                             !next_in_line.abo_booking? &&
                             !next_in_line.participant.ever_trialed_in_category?(course.category)

        if eligible_to_choose
          next_in_line.update!(status: "platz_frei", payment_expires_at: 7.days.from_now)
        else
          # Abo-Buchungen sind immer vorausbezahlt – niemals auf "ausstehend" setzen.
          new_status = (paid_course && !next_in_line.abo_booking?) ? "ausstehend" : "bestätigt"
          next_in_line.update!(status: new_status)
        end
        promoted << next_in_line
      end
    end

    promoted.each { |reg| CourseRegistrationMailer.waitlist_promoted(reg).deliver_later }
  end
end
