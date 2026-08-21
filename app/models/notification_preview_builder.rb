# Baut für die Benachrichtigungszentrale (NotificationCatalog) eine Vorschau jeder
# Mail — mit erfundenen Beispieldaten, NIE mit echten Datensätzen. Alle Objekte sind
# unsaved (nie in der DB), bekommen aber eine feste Fake-ID, damit URL-Helper im
# Mail-Template (z.B. course_registration_url) funktionieren, ohne die DB zu berühren.
#
# Jede Methode ruft die echte Mailer-Action auf (kein deliver!) und gibt das
# resultierende Mail::Message zurück – die Vorschau zeigt also exakt die echte Vorlage.
class NotificationPreviewBuilder
  FAKE_ID = 999_999_999

  class << self
    # ── Fake-Fabriken ──────────────────────────────────────────────────────
    def fake_parent
      with_id User.new(first_name: "Sandra", last_name: "Muster", email: "sandra.muster@beispiel.ch",
                        country: "CH", admin: false)
    end

    def fake_admin
      with_id User.new(first_name: "Peter", last_name: "Beispiel", email: "admin@beispiel.ch",
                        country: "CH", admin: true)
    end

    def fake_trainer_user
      with_id User.new(first_name: "Lisa", last_name: "Trainerin", email: "lisa.trainerin@beispiel.ch",
                        country: "CH", admin: false)
    end

    def fake_trainer
      with_id Trainer.new(user: fake_trainer_user, phone: "+41 79 123 45 67",
                           first_name: "Lisa", last_name: "Trainerin")
    end

    def fake_participant(user: fake_parent)
      with_id Participant.new(first_name: "Max", last_name: "Muster", user: user,
                               date_of_birth: 10.years.ago.to_date, gender: "männlich")
    end

    def fake_course(has_payment: true, has_ticketing: true, abo: false, title: "Kunstturnen Beispielkurs")
      c = with_id Course.new(
        title: title, registration_type: abo ? "abo" : "semester",
        has_payment: has_payment, has_ticketing: has_ticketing, price_cents: 15_000,
        category: "Turnen", max_participants: 12,
        start_date: 2.weeks.from_now.to_date, end_date: 4.months.from_now.to_date,
        abo_size: (abo ? 10 : nil)
      )
      c
    end

    def fake_training_session(course: fake_course)
      with_id TrainingSession.new(course: course, start_time: 2.days.from_now.change(hour: 18, min: 0),
                                   end_time: 2.days.from_now.change(hour: 19, min: 0))
    end

    def fake_registration(course: fake_course, participant: fake_participant, status: "bestätigt", **attrs)
      r = with_id CourseRegistration.new(course: course, participant: participant, status: status,
                                          payment_cleared: true, holiday_deduction_claimed: false, **attrs)
      r.created_at = Time.current
      r.updated_at = Time.current
      r
    end

    def with_id(record)
      record.id = FAKE_ID
      record
    end

    # ── Vorschau-Methoden (1:1 zu NotificationCatalog#preview_method) ───────

    def registration_confirmation
      CourseRegistrationMailer.confirmation(fake_registration(status: "bestätigt"))
    end

    def waitlist_promoted
      CourseRegistrationMailer.waitlist_promoted(fake_registration(status: "warteliste"))
    end

    def course_access_invited
      CourseAccessMailer.invited(fake_parent, fake_course)
    end

    def abo_imported
      CourseRegistrationMailer.abo_imported(fake_registration(course: fake_course(abo: true), status: "bestätigt", abo_entries_total: 10, abo_entries_used: 3))
    end

    def abo_exhausted
      CourseRegistrationMailer.abo_exhausted(fake_registration(course: fake_course(abo: true), status: "bestätigt", abo_entries_total: 10, abo_entries_used: 10))
    end

    def renewal_available
      old_course = fake_course(title: "Kunstturnen Beispielkurs (aktuelle Periode)")
      new_course = fake_course(title: "Kunstturnen Beispielkurs (nächste Periode)")
      CourseRegistrationMailer.renewal_available(fake_registration(course: old_course), new_course)
    end

    def self_cancelled
      CourseRegistrationMailer.self_cancelled(fake_registration(status: "storniert", cancelled_at: Time.current), refund_amount_cents: 15_000)
    end

    def cancelled_by_trainer
      reg = fake_registration(status: "storniert", cancellation_reason: "Verletzung, kann nicht mehr teilnehmen",
                               cancelled_by_trainer: fake_trainer)
      CourseRegistrationMailer.cancelled_by_trainer(reg)
    end

    def admin_cancel_notice
      reg = fake_registration(status: "storniert", cancelled_by_trainer: fake_trainer)
      CourseRegistrationMailer.admin_cancel_notice(reg, fake_admin)
    end

    def trainer_cancel_notice
      CourseRegistrationMailer.trainer_cancel_notice(fake_registration(status: "storniert"), fake_trainer_user)
    end

    def session_unsubscription
      ts = fake_training_session
      TrainingSessionMailer.session_unsubscription_notice(ts, fake_registration(course: ts.course), fake_admin)
    end

    def unsubscribe_reminder
      ts = fake_training_session
      TrainingSessionMailer.unsubscribe_reminder(ts, fake_registration(course: ts.course))
    end

    def training_cancelled
      TrainingSessionMailer.cancellation_notice(fake_training_session, fake_parent)
    end

    def training_cancelled_admin
      TrainingSessionMailer.training_cancelled_admin_notice(fake_training_session, fake_admin)
    end

    def payment_expired
      CourseRegistrationMailer.payment_expired(fake_registration(status: "ausstehend", payment_cleared: false))
    end

    def trial_expired
      CourseRegistrationMailer.trial_expired(fake_registration(status: "storniert", trial_expires_at: 1.day.ago))
    end

    def trial_date_changed
      session = fake_training_session
      CourseRegistrationMailer.trial_date_changed(
        fake_registration(course: session.course, status: "schnuppern", trial_session: session),
        previous_date: 3.days.from_now
      )
    end

    def payment_receipt
      reg = fake_registration(status: "bestätigt", sumup_transaction_id: "TX-BEISPIEL-123", sumup_checkout_id: "CO-BEISPIEL-456")
      CourseRegistrationMailer.payment_receipt(reg)
    end

    def payment_reminder
      PaymentReminderMailer.reminder(fake_registration(status: "ausstehend", payment_cleared: false, payment_reminder_count: 1))
    end

    def refund_failed_notice
      CourseRegistrationMailer.refund_failed_notice(fake_registration(status: "storniert"), fake_admin, "SumUp: Verbindung fehlgeschlagen", 15_000)
    end

    def admin_refund_done_notice
      reg = fake_registration(status: "storniert", cancelled_by_trainer: fake_trainer)
      CourseRegistrationMailer.admin_refund_done_notice(reg, fake_admin, 15_000)
    end

    def trainer_assigned
      CourseTrainerMailer.assigned_to_course(fake_trainer, fake_course)
    end

    def trainer_invitation
      TrainerInvitationMailer.invite(fake_trainer, "beispiel-token-abc123")
    end

    def attendance_reminder_trainer
      AttendanceReminderMailer.trainer_reminder(fake_training_session, fake_trainer)
    end

    def attendance_reminder_admin
      AttendanceReminderMailer.admin_notification_for(fake_training_session, fake_admin)
    end

    def substitute_assigned
      TrainingSessionMailer.substitute_assigned(fake_training_session, fake_trainer)
    end

    def substitute_assigned_admin
      session = fake_training_session
      session.substitute_reason = "Bin an diesem Tag krank."
      TrainingSessionMailer.substitute_assigned_admin_notice(session, fake_trainer, fake_admin)
    end

    def custom_trainer_message
      CourseRegistrationMailer.custom_message(
        fake_registration, subject: "Wichtige Info zum Training", sender: fake_trainer,
        body: "Hallo zusammen,\n\ndas Training am Mittwoch fällt leider aus.\n\nSportliche Grüsse\nLisa"
      )
    end

    def participant_complete_profile
      ParticipantMailer.complete_profile(fake_participant, fake_course)
    end

    def course_rollover_ready
      CourseRolloverMailer.ready_for_manual_rollover(fake_course)
    end
  end
end
