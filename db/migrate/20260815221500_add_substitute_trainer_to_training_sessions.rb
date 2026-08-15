class AddSubstituteTrainerToTrainingSessions < ActiveRecord::Migration[8.1]
  def change
    add_reference :training_sessions, :substitute_trainer, foreign_key: { to_table: :trainers }, null: true
  end
end
