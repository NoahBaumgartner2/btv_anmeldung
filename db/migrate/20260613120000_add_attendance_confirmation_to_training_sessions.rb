class AddAttendanceConfirmationToTrainingSessions < ActiveRecord::Migration[8.1]
  def up
    add_column :training_sessions, :attendance_confirmed_at, :datetime
    add_reference :training_sessions, :attendance_confirmed_by,
                  foreign_key: { to_table: :users }, null: true

    # Backfill: Bestehende, bereits vergangene Sessions mit mindestens einem
    # Anwesenheitseintrag gelten als abgeschlossen – damit sie nach der
    # Umstellung von attendance_recorded? keine Mahnungsflut auslösen.
    execute <<~SQL.squish
      UPDATE training_sessions
      SET attendance_confirmed_at = COALESCE(end_time, start_time)
      WHERE end_time < NOW()
        AND EXISTS (
          SELECT 1 FROM attendances
          WHERE attendances.training_session_id = training_sessions.id
        )
    SQL
  end

  def down
    remove_reference :training_sessions, :attendance_confirmed_by,
                     foreign_key: { to_table: :users }
    remove_column :training_sessions, :attendance_confirmed_at
  end
end
