class AddRefundedAtToCourseRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :course_registrations, :refunded_at, :datetime
  end
end
