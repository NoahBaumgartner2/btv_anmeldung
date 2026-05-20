class AddCanManuallyEnrollToCourseTrainers < ActiveRecord::Migration[8.1]
  def change
    add_column :course_trainers, :can_manually_enroll, :boolean, default: false, null: false
  end
end
