class AddPerformanceIndexes < ActiveRecord::Migration[8.1]
  def change
    unless index_exists?(:course_registrations, :status)
      add_index :course_registrations, :status
    end

    unless index_exists?(:attendances, [ :training_session_id, :course_registration_id ])
      add_index :attendances, [ :training_session_id, :course_registration_id ],
        unique: true,
        name: "index_attendances_unique_per_session"
    end

    unless index_exists?(:participants, :ahv_number)
      add_index :participants, :ahv_number
    end
  end
end
