class AddMailToggleColumnsToMailSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :mail_settings, :mail_registration_confirmation_enabled, :boolean, default: true, null: false
    add_column :mail_settings, :mail_waitlist_promoted_enabled,          :boolean, default: true, null: false
    add_column :mail_settings, :mail_cancelled_by_trainer_enabled,       :boolean, default: true, null: false
    add_column :mail_settings, :mail_payment_expired_enabled,            :boolean, default: true, null: false
    add_column :mail_settings, :mail_course_access_invited_enabled,      :boolean, default: true, null: false
  end
end
