class FixUniqueIndexCourseRegistrationsSemesterOnly < ActiveRecord::Migration[8.1]
  def change
    remove_index :course_registrations, name: "index_course_registrations_unique_active", if_exists: true
    add_index :course_registrations, [ :participant_id, :course_id ],
      unique: true,
      where: "training_session_id IS NULL AND status NOT IN ('storniert', 'ausstehend')",
      name: "index_course_registrations_unique_active"
  end
end
