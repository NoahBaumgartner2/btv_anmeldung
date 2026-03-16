class CreateCourseRegistrations < ActiveRecord::Migration[8.1]
  def change
    create_table :course_registrations do |t|
      t.references :course, null: false, foreign_key: true
      t.references :registration, null: false, foreign_key: true

      t.timestamps
    end
  end
end
