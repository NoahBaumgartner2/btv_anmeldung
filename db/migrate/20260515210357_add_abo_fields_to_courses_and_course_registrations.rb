class AddAboFieldsToCoursesAndCourseRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :abo_size, :integer
    add_column :course_registrations, :abo_entries_total, :integer
    add_column :course_registrations, :abo_entries_used, :integer, default: 0
  end
end
