class CreateRegistrations < ActiveRecord::Migration[8.1]
  def change
    create_table :registrations do |t|
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :phone_number
      t.string :ahv_number
      t.date :date_of_birth
      t.string :gender

      t.timestamps
    end
  end
end
