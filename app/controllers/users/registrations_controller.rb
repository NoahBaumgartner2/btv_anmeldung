class Users::RegistrationsController < Devise::RegistrationsController
  def create
    super do |user|
      if user.persisted? && params.dig(:user, :newsletter_opt_in) == "1"
        sub = NewsletterSubscriber.find_or_initialize_by(email: user.email.downcase.strip)
        sub.status = "subscribed"
        sub.source ||= "registration"
        sub.save!
      end
    rescue => e
      Rails.logger.error "[Registration] Newsletter-Anmeldung fehlgeschlagen: #{e.message}"
    end
  end
end
