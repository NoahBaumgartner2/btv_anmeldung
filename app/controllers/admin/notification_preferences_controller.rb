module Admin
  class NotificationPreferencesController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_trainer!

    def edit
      # zeigt das Formular für current_user
    end

    def update
      prefs = {}
      User::ADMIN_NOTIFICATION_TYPES.each do |type|
        prefs[type] = params.dig(:preferences, type) == "1"
      end

      if current_user.update(admin_notification_preferences: prefs)
        redirect_to edit_admin_notification_preferences_path,
                    notice: "Benachrichtigungseinstellungen gespeichert."
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end
end
