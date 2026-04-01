class ApplicationController < ActionController::Base
  # Erlaubt moderne Browser-Features wie Web-Push (Standard von Rails 8)
  allow_browser versions: :modern

  private

private

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
end
