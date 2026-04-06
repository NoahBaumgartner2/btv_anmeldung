class ExportProfileMailer < ApplicationMailer
  def scheduled_export(export_profile, participants)
    @profile = export_profile

    csv_data = @profile.generate_csv(participants)
    filename = "#{@profile.name.parameterize}-#{Date.today}.csv"

    # UTF-8 BOM für Excel-Kompatibilität voranstellen
    attachments[filename] = {
      mime_type: "text/csv",
      content:   "\xEF\xBB\xBF#{csv_data}"
    }

    mail(
      to:      @profile.recipient_email,
      subject: "[Export] #{@profile.name} - #{Date.today.strftime('%d.%m.%Y')}"
    )
  end
end
