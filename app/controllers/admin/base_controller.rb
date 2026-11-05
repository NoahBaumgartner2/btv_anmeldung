module Admin
  # Gemeinsame Basis aller reinen Admin-Seiten: Login + Admin-Prüfung an einer Stelle.
  # Ausnahme: NotificationPreferencesController (auch für Trainer:innen) erbt
  # weiterhin direkt von ApplicationController.
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_admin!
  end
end
