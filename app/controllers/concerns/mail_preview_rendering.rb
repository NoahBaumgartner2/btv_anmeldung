# Zeigt eine Mail wie im Mailprogramm: Kopf (Betreff, Von, An, Datum) und darunter
# das Mail-HTML mit seinen Inline-Styles. Genutzt von der Benachrichtigungszentrale
# (Beispieldaten) und vom Mail-Protokoll (tatsächlich versendete Mail).
module MailPreviewRendering
  extend ActiveSupport::Concern

  private

  def render_mail_preview(html:, subject:, from:, recipients:, sent_at:, sample: false)
    doc = Nokogiri::HTML(html.to_s)
    # Mail-HTML arbeitet mit Inline-Styles (wie jedes Mailprogramm sie anzeigt). Die
    # App-CSP verbietet sie; nur für diese Vorschau: Inline-Styles ja, Skripte nein.
    # Die CSP-Middleware überschreibt einen bereits gesetzten Header nicht.
    response.headers["Content-Security-Policy"] =
      "default-src 'none'; style-src 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; base-uri 'none'; form-action 'none'"
    render template: "shared/mail_preview", layout: false, locals: {
      subject: subject, from: from.to_s, recipients: Array(recipients), sent_at: sent_at, sample: sample,
      body_style: doc.at("body")&.[]("style"), body_html: doc.at("body")&.inner_html.to_s
    }
  end
end
