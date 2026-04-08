class AddJsImportFieldsToParticipants < ActiveRecord::Migration[8.1]
  def change
    add_column :participants, :nationality, :string, default: "CH"
    add_column :participants, :mother_tongue, :string, default: "DE"
    add_column :participants, :street, :string
    add_column :participants, :house_number, :string
    add_column :participants, :zip_code, :string
    add_column :participants, :city, :string
    add_column :participants, :country, :string, default: "CH"
    add_column :participants, :js_person_number, :string
  end
end
