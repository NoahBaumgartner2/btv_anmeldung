class AddSelfParticipantToTrainers < ActiveRecord::Migration[8.1]
  def change
    add_column :participants, :is_trainer_self, :boolean, default: false, null: false
    add_reference :trainers, :self_participant, foreign_key: { to_table: :participants }, null: true
  end
end
