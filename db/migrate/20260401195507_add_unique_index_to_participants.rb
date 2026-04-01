class AddUniqueIndexToParticipants < ActiveRecord::Migration[8.1]
  def change
    add_index :participants, [:first_name, :last_name, :date_of_birth, :user_id],
              unique: true,
              name: "index_participants_unique_per_user"
  end
end
