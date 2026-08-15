class AddCancellationReasonToTrainingSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :training_sessions, :cancellation_reason, :text
  end
end
