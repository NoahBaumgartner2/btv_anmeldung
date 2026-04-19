class ScheduledExportJob < ApplicationJob
  queue_as :default

  # Wird von Solid Queue recurring tasks aufgerufen.
  # frequency: "daily" | "weekly" | "monthly"
  def perform(frequency)
    ExportProfile.where(schedule: frequency).find_each do |profile|
      next unless profile.recipient_email.present?
      participants = build_participants_scope(profile)
      ExportProfileMailer.scheduled_export(profile, participants).deliver_now
    rescue Net::SMTPError, Net::OpenTimeout, Net::ReadTimeout, SocketError,
           Errno::ECONNREFUSED, EOFError => e
      Rails.logger.error "[ScheduledExportJob] Fehler bei Profil #{profile.id}: #{e.class}: #{e.message}"
    end
  end

  private

  def build_participants_scope(profile)
    scope = Participant.includes(:user, :courses).joins(:user)
    scope = scope.joins(:course_registrations).where(course_registrations: { course_id: profile.course_id }) if profile.course_id?
    scope.order(last_name: :asc, first_name: :asc)
  end
end
