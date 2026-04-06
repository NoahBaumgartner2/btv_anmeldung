class RemoveEmailFromParticipants < ActiveRecord::Migration[8.1]
  def change
    remove_column :participants, :email, :string
  end
end
