class Users::RegistrationsController < Devise::RegistrationsController
  def create
    super do |user|
      if user.persisted? && params.dig(:user, :newsletter_opt_in) == "1"
        NewsletterSubscriber.find_or_create_by!(email: user.email.downcase.strip) do |sub|
          sub.status = "subscribed"
          sub.source = "registration"
        end
      end
    rescue => e
      Rails.logger.error "[Registration] Newsletter-Anmeldung fehlgeschlagen: #{e.message}"
    end
  end
end
