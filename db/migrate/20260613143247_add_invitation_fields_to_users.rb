class AddInvitationFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :invitation_kind, :string
    add_column :users, :invitation_expires_at, :datetime
  end
end
