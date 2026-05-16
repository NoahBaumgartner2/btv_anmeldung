class AddPersonalDataToTrainers < ActiveRecord::Migration[8.1]
  def change
    add_column :trainers, :first_name,      :string
    add_column :trainers, :last_name,        :string
    add_column :trainers, :date_of_birth,    :date
    add_column :trainers, :gender,           :string
    add_column :trainers, :ahv_number,       :string
    add_column :trainers, :street,           :string
    add_column :trainers, :house_number,     :string
    add_column :trainers, :zip_code,         :string
    add_column :trainers, :city,             :string
    add_column :trainers, :country,          :string, default: "CH"
    add_column :trainers, :nationality,      :string, default: "CH"
    add_column :trainers, :mother_tongue,    :string, default: "DE"
    add_column :trainers, :js_person_number, :string
  end
end
