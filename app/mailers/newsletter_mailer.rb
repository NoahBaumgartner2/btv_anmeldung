class NewsletterMailer < ApplicationMailer
  def campaign(newsletter, subscriber)
    @newsletter  = newsletter
    @subscriber  = subscriber
    @unsubscribe_url = unsubscribe_newsletter_subscriber_url(subscriber)

    mail(
      to:      subscriber.email,
      subject: newsletter.subject
    )
  end
end
