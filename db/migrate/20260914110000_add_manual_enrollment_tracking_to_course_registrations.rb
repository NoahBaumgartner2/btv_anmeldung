class AddManualEnrollmentTrackingToCourseRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :course_registrations, :manually_enrolled, :boolean, default: false, null: false
    add_column :course_registrations, :manual_enrollment_reminder_sent_at, :datetime
  end
end
