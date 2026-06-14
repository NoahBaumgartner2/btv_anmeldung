class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [ :create ]

  def create
    super do |user|
      next unless user.persisted?

      begin
        sub = NewsletterSubscriber.find_or_initialize_by(email: user.email.downcase.strip)
        sub.status = "subscribed"
        # Quelle nur bei neuen Abos setzen; bestehende Herkunft (z.B. csv_import) bleibt erhalten.
        # (source hat den DB-Default "manual", daher kein ||=, das nie "registration" ergäbe.)
        sub.source = "registration" if sub.new_record?
        sub.save!
      rescue => e
        Rails.logger.error "[Registration] Newsletter-Anmeldung fehlgeschlagen: #{e.message}"
      end
    end

    if resource.persisted? && resource.devise_notification_error
      flash[:alert] = t("devise.registrations.confirmation_email_failed")
    end
  end

  protected

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :privacy_accepted, :photo_consent_accepted, :first_name, :last_name ])
  end
end
