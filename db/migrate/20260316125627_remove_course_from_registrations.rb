class RemoveCourseFromRegistrations < ActiveRecord::Migration[8.1]
  def change
    remove_reference :registrations, :course, null: false, foreign_key: true
  end
end
