class AddTalentFlagToCourseRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :course_registrations, :talent_flag, :boolean, default: false, null: false
    add_column :course_registrations, :talent_note, :text
  end
end
