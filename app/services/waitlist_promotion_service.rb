# Kapselt die Hochstufungs-Logik, wenn ein bestätigter Platz frei wird.
# Genutzt von CourseRegistrationsController nach cancel, trainer_cancel und destroy.
class WaitlistPromotionService
  MAX_PROMOTIONS_PER_CALL = 10

  # Stündlicher Sweep (ExpirePendingPaymentsJob): rückt Wartelisten in Kursen
  # nach, die freie Plätze haben, ohne dass eine Stornierung das Nachrücken
  # ausgelöst hat - v.a. Rollover-Nachfolgekurse, sobald das Vorrang-Fenster
  # endet (beim Rollover selbst wird bewusst nicht nachgerückt). Kurse mit
  # offenen Checkouts ("ausstehend") werden ausgelassen, damit ein bisheriger
  # Teilnehmer, der gerade bezahlt, nicht überbucht wird; deren Verfall löst
  # das Nachrücken ohnehin aus.
  def self.promote_open_waitlists
    course_ids = CourseRegistration.where(status: "warteliste", training_session_id: nil).select(:course_id)
    Course.where(id: course_ids).where.not(registration_type: "pro_training").find_each do |course|
      next if course.end_date.present? && course.end_date < Date.current
      next unless course.registration_window_open_for?(nil)
      next if course.course_registrations.where(status: "ausstehend", training_session_id: nil).exists?

      promote_next_from_waitlist(course)
    end
  end

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
      # Kein Nachrücken in beendeten oder bereits verlängerten Kursen: die
      # Warteliste lebt im Nachfolge-Kurs weiter (copy_waitlist), sonst zahlt
      # man für ein Quartal, das vorbei ist.
      return if course.ended? || course.next_course.present?

      # Bei Drop-In-Kursen hat jedes Training sein eigenes Limit (siehe
      # TrainingSession#effective_max_participants); sonst gilt das Kurs-Limit.
      limit = if training_session_id.present?
        TrainingSession.find(training_session_id).effective_max_participants
      else
        course.max_participants
      end
      return if limit.blank?

      paid_course = course.has_payment? && course.price_cents.to_i > 0
      # Belegte Plätze: einheitliche Definition über CourseRegistration::OCCUPYING_STATUSES
      # (bestätigt/schnuppern/platz_frei – bewusst OHNE "ausstehend", siehe Konstante).
      confirmed_scope = course.course_registrations.where(status: CourseRegistration::OCCUPYING_STATUSES)
      waitlist_scope  = course.course_registrations.where(status: "warteliste")

      if training_session_id.present?
        confirmed_scope = confirmed_scope.where(training_session_id: training_session_id)
        waitlist_scope  = waitlist_scope.where(training_session_id: training_session_id)
      else
        confirmed_scope = confirmed_scope.where(training_session_id: nil)
        waitlist_scope  = waitlist_scope.where(training_session_id: nil)
      end

      MAX_PROMOTIONS_PER_CALL.times do
        break if confirmed_scope.distinct.count(:participant_id) >= limit

        next_in_line = waitlist_scope.order(:created_at).first
        break unless next_in_line

        # Darf der Teilnehmer in dieser Kategorie noch schnuppern (hat seine einmalige
        # Schnuppermöglichkeit noch nicht genutzt)? Dann bekommt er den Platz "auf Probe":
        # Status "platz_frei" mit 5-Tage-Frist, und entscheidet selbst zwischen Schnuppern
        # und regulärer Anmeldung (siehe CourseRegistrations#accept_spot). Hinweis: bewusst
        # ever_trialed_in_category? (nicht schnupper_eligible_for_category?), da die eigene
        # Wartelisten-Anmeldung sich sonst selbst als "bereits registriert" blockieren würde.
        eligible_to_choose = course.allows_trial? &&
                             !next_in_line.abo_booking? &&
                             !next_in_line.participant.ever_trialed_in_category?(course.category)

        if eligible_to_choose
          next_in_line.update!(status: "platz_frei", payment_expires_at: 5.days.from_now)
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
