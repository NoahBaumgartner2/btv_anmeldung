class AddUniqueIndexCourseRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_index :course_registrations, [ :participant_id, :course_id ],
      unique: true,
      where: "training_session_id IS NULL AND (status IS NULL OR status NOT IN ('storniert', 'ausstehend'))",
      name: "index_course_registrations_unique_active"

    add_index :course_registrations, [ :participant_id, :training_session_id ],
      unique: true,
      where: "training_session_id IS NOT NULL AND status NOT IN ('storniert', 'ausstehend')",
      name: "index_course_registrations_unique_session"
  end
end
