class AddAdminNotificationPreferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :admin_notification_preferences, :jsonb, default: {}, null: false
  end
end
