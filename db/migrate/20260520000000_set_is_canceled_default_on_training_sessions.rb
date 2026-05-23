class SetIsCanceledDefaultOnTrainingSessions < ActiveRecord::Migration[8.1]
  def change
    # Backfill NULL values that were created without an explicit is_canceled value
    TrainingSession.where(is_canceled: nil).update_all(is_canceled: false)
    change_column_default :training_sessions, :is_canceled, from: nil, to: false
    change_column_null :training_sessions, :is_canceled, false, false
  end
end
