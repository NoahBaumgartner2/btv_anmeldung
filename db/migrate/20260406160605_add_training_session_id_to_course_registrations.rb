class AddTrainingSessionIdToCourseRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :course_registrations, :training_session_id, :bigint
    add_foreign_key :course_registrations, :training_sessions, column: :training_session_id
    add_index :course_registrations, :training_session_id
  end
end
