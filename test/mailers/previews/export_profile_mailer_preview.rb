# Preview all emails at http://localhost:3000/rails/mailers/export_profile_mailer
class ExportProfileMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/export_profile_mailer/scheduled_export
  def scheduled_export
    ExportProfileMailer.scheduled_export
  end
end
