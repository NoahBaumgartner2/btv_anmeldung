class AddPaymentExpiresAtToCourseRegistrations < ActiveRecord::Migration[8.0]
  def change
    add_column :course_registrations, :payment_expires_at, :datetime
  end
end
