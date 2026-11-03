class AddMoveTrackingToCourseRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :course_registrations, :moved_at, :datetime
    add_column :course_registrations, :sessions_before_move, :integer, null: false, default: 0
  end
end
