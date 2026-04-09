class AddTrainerCancellationFieldsToCourseRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :course_registrations, :cancellation_reason, :text
    add_column :course_registrations, :cancellation_notify_admin, :boolean, default: false, null: false
    add_column :course_registrations, :cancelled_at, :datetime
    add_reference :course_registrations, :cancelled_by_trainer,
                  foreign_key: { to_table: :trainers }, null: true
  end
end
