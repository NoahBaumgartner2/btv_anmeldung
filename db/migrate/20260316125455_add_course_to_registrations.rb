class AddCourseToRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_reference :registrations, :course, null: false, foreign_key: true
  end
end
