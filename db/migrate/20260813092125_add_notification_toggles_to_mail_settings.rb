class AddNotificationTogglesToMailSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :mail_settings, :notification_toggles, :jsonb, default: {}, null: false
  end
end
