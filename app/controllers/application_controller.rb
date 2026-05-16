class ApplicationController < ActionController::Base
  # Erlaubt moderne Browser-Features wie Web-Push (Standard von Rails 8)
  allow_browser versions: :modern

  before_action :set_locale
  before_action :redirect_to_onboarding_if_needed

  def default_url_options
    { locale: nil }
  end

  private

  def redirect_to_onboarding_if_needed
    return unless user_signed_in?
    return if current_user.admin? || Trainer.exists?(user: current_user)
    return if controller_name == "onboarding"
    return if devise_controller?
    return if controller_path.start_with?("rails/")
    return unless current_user.needs_onboarding?
    redirect_to onboarding_path
  end

  def set_locale
    I18n.locale = session[:locale] || I18n.default_locale
  end

  # Türsteher 1: NUR für Reto (Admin)
  def authorize_admin!
    unless user_signed_in? && current_user.admin?
      redirect_to root_path, alert: "Zugriff verweigert! Diese Seite ist nur für den Administrator."
    end
  end

  # Türsteher 2: Für Trainer (und Reto darf natürlich auch rein)
  def authorize_trainer!
    unless user_signed_in? && (current_user.admin? || Trainer.exists?(user: current_user))
      redirect_to root_path, alert: "Zugriff verweigert! Du musst Trainer sein, um das zu sehen."
    end
  end

  # Türsteher 3: Elternteil darf nur die eigenen Kinder bearbeiten
  def authorize_parent_owns_registration!(registration)
    unless current_user.participants.include?(registration.participant)
      redirect_to root_path, alert: "Zugriff verweigert."
    end
  end
end
