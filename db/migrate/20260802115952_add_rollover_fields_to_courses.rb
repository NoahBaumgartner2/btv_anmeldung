class AddRolloverFieldsToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :renewal_priority_weeks, :integer, default: 3
    add_column :courses, :public_registration_weeks, :integer, default: 1
    add_reference :courses, :previous_course, null: true, foreign_key: { to_table: :courses }, index: { unique: true }
  end
end
