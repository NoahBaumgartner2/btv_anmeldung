class TestMailer < ApplicationMailer
  def test_email(to_address)
    mail(
      to:      to_address,
      subject: "BTV Anmeldeportal – Test-E-Mail"
    )
  end
end
