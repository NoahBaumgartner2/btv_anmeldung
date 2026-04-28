class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [:create]

  def create
    super do |user|
      next unless user.persisted?

      if params.dig(:user, :newsletter_opt_in) == "1"
        sub = NewsletterSubscriber.find_or_initialize_by(email: user.email.downcase.strip)
        sub.status = "subscribed"
        sub.source ||= "registration"
        sub.save!
      end
    rescue => e
      Rails.logger.error "[Registration] Newsletter-Anmeldung fehlgeschlagen: #{e.message}"
    end
  end

  protected

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [:privacy_accepted])
  end
end
