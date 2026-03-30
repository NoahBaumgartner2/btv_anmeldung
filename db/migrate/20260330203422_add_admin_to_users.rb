class AddAdminToUsers < ActiveRecord::Migration[8.1]
  def change
    # WICHTIG: , default: false hinzufügen!
    add_column :users, :admin, :boolean, default: false
  end
end