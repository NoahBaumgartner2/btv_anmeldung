class ApplicationController < ActionController::Base
  # Erlaubt moderne Browser-Features wie Web-Push (Standard von Rails 8)
  allow_browser versions: :modern

  before_action :set_locale
  before_action :redirect_to_onboarding_if_needed
  before_action :redirect_to_incomplete_participant_if_needed
  before_action :redirect_trainer_to_profile_if_incomplete

  def default_url_options
    { locale: nil }
  end

  private

  def redirect_to_onboarding_if_needed
    return unless user_signed_in?
    return if current_user.admin? || Trainer.exists?(user: current_user)
    return if controller_name.in?(%w[onboarding sessions registrations passwords confirmations])
    return if devise_controller?
    return if controller_path.start_with?("rails/")
    return unless current_user.needs_onboarding?
    redirect_to onboarding_path
  end

  # Platzhalter-Teilnehmer aus einer E-Mail-only-Anmeldung (siehe
  # courses_controller#enroll_participant) haben kein Geburtsdatum – solange
  # eines fehlt, muss die Familie das Profil zwingend vervollständigen, bevor
  # sie irgendwo anders hin navigiert (statt nur einen Hinweis zu sehen).
  def redirect_to_incomplete_participant_if_needed
    return unless user_signed_in?
    return if current_user.admin? || Trainer.exists?(user: current_user)
    return if controller_name.in?(%w[onboarding sessions registrations passwords confirmations])
    return if controller_name == "participants" && action_name.in?(%w[edit update])
    return if devise_controller?
    return if controller_path.start_with?("rails/")
    return if current_user.needs_onboarding?

    incomplete = current_user.participants.find_by(date_of_birth: nil)
    return unless incomplete

    redirect_to edit_participant_path(incomplete),
      alert: "Bitte ergänze zuerst die Angaben für #{incomplete.first_name} #{incomplete.last_name}."
  end

  def redirect_trainer_to_profile_if_incomplete
    return unless user_signed_in?
    return if current_user.admin?
    return if devise_controller?
    return if controller_path.start_with?("rails/")
    return if controller_name.in?(%w[locales pages])
    return if controller_name == "participants" && action_name == "my_profile"
    return if controller_name == "trainers" && action_name == "update_profile"

    trainer = Trainer.find_by(user: current_user)
    return unless trainer
    return if trainer.profile_complete?

    redirect_to my_profile_path, alert: t("trainers.profile_incomplete_alert")
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
