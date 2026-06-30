module Admin
  # Zentraler Einstellungs-Hub mit vier Tabs. Rendert die jeweils eingebetteten
  # Formulare der bestehenden Singleton-Settings; die Formulare posten weiterhin
  # an ihre eigenen Controller (MailSettings, Admin::PaymentSettings, …).
  class SettingsController < ApplicationController
    include SettingsLoadable

    before_action :authenticate_user!
    before_action :authorize_admin!

    def communication
      load_communication_settings
    end

    def club
      load_club_settings
    end

    def payments
      load_payment_settings
    end

    def data
      load_data_settings
    end
  end
end
