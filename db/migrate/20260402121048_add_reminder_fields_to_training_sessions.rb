class AddReminderFieldsToTrainingSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :training_sessions, :trainer_reminded_at, :datetime
    add_column :training_sessions, :admin_notified_at, :datetime
  end
end
