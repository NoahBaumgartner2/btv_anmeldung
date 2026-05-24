class AddUniqueIndexCourseRegistrations < ActiveRecord::Migration[8.1]
  def change
    # Duplikate für den ersten Index bereinigen (ohne training_session_id, aktive Einträge)
    execute <<-SQL
      DELETE FROM course_registrations
      WHERE id NOT IN (
        SELECT DISTINCT ON (participant_id, course_id) id
        FROM course_registrations
        WHERE training_session_id IS NULL
          AND (status IS NULL OR status NOT IN ('storniert', 'ausstehend'))
        ORDER BY participant_id, course_id, id DESC
      )
      AND training_session_id IS NULL
      AND (status IS NULL OR status NOT IN ('storniert', 'ausstehend'))
    SQL

    # Duplikate für den zweiten Index bereinigen (mit training_session_id, aktive Einträge)
    execute <<-SQL
      DELETE FROM course_registrations
      WHERE id NOT IN (
        SELECT DISTINCT ON (participant_id, training_session_id) id
        FROM course_registrations
        WHERE training_session_id IS NOT NULL
          AND (status IS NULL OR status NOT IN ('storniert', 'ausstehend'))
        ORDER BY participant_id, training_session_id, id DESC
      )
      AND training_session_id IS NOT NULL
      AND (status IS NULL OR status NOT IN ('storniert', 'ausstehend'))
    SQL

    add_index :course_registrations, [ :participant_id, :course_id ],
      unique: true,
      where: "training_session_id IS NULL AND (status IS NULL OR status NOT IN ('storniert', 'ausstehend'))",
      name: "index_course_registrations_unique_active"

    add_index :course_registrations, [ :participant_id, :training_session_id ],
      unique: true,
      where: "training_session_id IS NOT NULL AND (status IS NULL OR status NOT IN ('storniert', 'ausstehend'))",
      name: "index_course_registrations_unique_session"
  end
end
