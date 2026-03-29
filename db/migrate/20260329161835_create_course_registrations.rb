class CreateCourseRegistrations < ActiveRecord::Migration[8.1]
  def change
    create_table :course_registrations do |t|
      t.references :course, null: false, foreign_key: true
      t.references :participant, null: false, foreign_key: true
      t.string :status
      t.boolean :payment_cleared
      t.boolean :holiday_deduction_claimed

      t.timestamps
    end
  end
end
