class ApplicationController < ActionController::Base
  # Erlaubt moderne Browser-Features wie Web-Push (Standard von Rails 8)
  allow_browser versions: :modern

  private

  # Unser neuer Türsteher für den Admin-Bereich!
  def authorize_admin!
    # Wenn der User nicht eingeloggt ist, oder kein Trainer-Profil hat: Raus hier!
    unless user_signed_in? && Trainer.exists?(user: current_user)
      redirect_to profil_path, alert: "Zugriff verweigert! Du hast keine Admin-Rechte für diese Seite."
    end
  end
end
