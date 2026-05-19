class ExpireTrialRegistrationsJob < ApplicationJob
  queue_as :default

  def perform
    scope = CourseRegistration
      .where(status: "schnuppern")
      .where("created_at < ?", 7.days.ago)

    total     = scope.count
    cancelled = 0
    errors    = 0

    Rails.logger.info "[ExpireTrialRegistrationsJob] #{total} abgelaufene Schnupper-Anmeldung(en) gefunden."

    scope.includes(:course, participant: :user).find_each do |registration|
      registration.with_lock do
        next if registration.status != "schnuppern"

        registration.update!(status: "storniert")

        WaitlistPromotionService.promote_next_from_waitlist(
          registration.course,
          training_session_id: registration.training_session_id
        )
      end

      Rails.logger.info "[ExpireTrialRegistrationsJob] Registration #{registration.id} storniert."
      cancelled += 1
    rescue => e
      errors += 1
      Rails.logger.error "[ExpireTrialRegistrationsJob] Fehler bei Registration #{registration.id}: #{e.class}: #{e.message}"
    end

    Rails.logger.info "[ExpireTrialRegistrationsJob] Abgeschlossen: #{total} geprüft, #{cancelled} storniert, #{errors} Fehler."
  end
end
