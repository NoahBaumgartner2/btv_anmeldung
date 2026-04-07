class AddPaymentReminderCountToCourseRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :course_registrations, :payment_reminder_count, :integer, default: 0, null: false
  end
end
