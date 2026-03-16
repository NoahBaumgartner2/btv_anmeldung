class CreateCourses < ActiveRecord::Migration[8.1]
  def change
    create_table :courses do |t|
      t.string :title
      t.text :description
      t.string :location
      t.datetime :start_date
      t.datetime :end_date
      t.boolean :allows_holiday_deduction
      t.string :registration_type
      t.boolean :has_ticketing
      t.boolean :has_payment

      t.timestamps
    end
  end
end
