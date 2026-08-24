class AddMaxParticipantsToTrainingSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :training_sessions, :max_participants, :integer
  end
end
