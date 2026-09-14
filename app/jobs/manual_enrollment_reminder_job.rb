# Erinnert Familien, die von einem Admin/Trainer manuell zu einem Kurs
# hinzugefügt wurden (siehe CoursesController#enroll_participant), aber 7 Tage
# später weder ihr Konto eingerichtet (family_data_completed) noch - falls
# nötig - bezahlt haben. Betrifft nur manuell hinzugefügte Anmeldungen: die
# Selbstanmeldung läuft über eine eigene Zahlungsfrist (siehe
# ExpirePendingPaymentsJob) und braucht diese Erinnerung nicht.
class ManualEnrollmentReminderJob < ApplicationJob
  queue_as :default

  def perform
    scope = CourseRegistration
      .where(manually_enrolled: true, manual_enrollment_reminder_sent_at: nil)
      .where.not(status: "storniert")
      .where("created_at <= ?", 7.days.ago)

    sent = 0

    scope.includes(:course, participant: :user).find_each do |registration|
      user = registration.participant.user
      next if user.nil?

      account_missing = !user.family_data_completed?
      payment_missing = registration.payment_required? && !registration.payment_cleared?
      next unless account_missing || payment_missing

      CourseRegistrationMailer.manual_enrollment_reminder(
        registration, account_missing: account_missing, payment_missing: payment_missing
      ).deliver_later
      registration.update_column(:manual_enrollment_reminder_sent_at, Time.current)
      sent += 1
    rescue => e
      Rails.logger.error "[ManualEnrollmentReminderJob] Fehler bei Registration #{registration.id}: #{e.class}: #{e.message}"
    end

    Rails.logger.info "[ManualEnrollmentReminderJob] #{sent} Erinnerung(en) verschickt."
  end
end
