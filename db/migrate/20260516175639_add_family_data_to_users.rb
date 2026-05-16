class AddFamilyDataToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :phone_number, :string
    add_column :users, :street, :string
    add_column :users, :house_number, :string
    add_column :users, :zip_code, :string
    add_column :users, :city, :string
    add_column :users, :country, :string, default: "CH"
    add_column :users, :nationality, :string, default: "CH"
    add_column :users, :mother_tongue, :string, default: "DE"
    add_column :users, :family_data_completed, :boolean, default: false, null: false

    User.joins(:participants).distinct.update_all(family_data_completed: true)
  end
end
