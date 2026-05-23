class AddPerformanceIndexesToCourseRegistrations < ActiveRecord::Migration[8.1]
  def change
    # :status allein existiert bereits (20260523100002), nur fehlende Composite-Indexes ergänzen
    unless index_exists?(:course_registrations, [ :course_id, :status ])
      add_index :course_registrations, [ :course_id, :status ]
    end

    unless index_exists?(:course_registrations, :payment_expires_at)
      add_index :course_registrations, :payment_expires_at,
        where: "payment_expires_at IS NOT NULL",
        name: "index_course_registrations_on_payment_expires_at_not_null"
    end
  end
end
