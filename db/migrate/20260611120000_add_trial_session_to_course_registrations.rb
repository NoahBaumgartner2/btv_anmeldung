class AddTrialSessionToCourseRegistrations < ActiveRecord::Migration[8.1]
  def up
    add_reference :course_registrations, :trial_session,
                  foreign_key: { to_table: :training_sessions }, null: true
    add_column :course_registrations, :trial_expires_at, :datetime

    # Backfill: bestehende Schnupper-Anmeldungen behalten die alte Frist
    # (Anmeldezeitpunkt + 7 Tage), damit der Job sie korrekt ablaufen lässt.
    execute <<~SQL.squish
      UPDATE course_registrations
      SET trial_expires_at = created_at + INTERVAL '7 days'
      WHERE status = 'schnuppern' AND trial_expires_at IS NULL
    SQL
  end

  def down
    remove_column :course_registrations, :trial_expires_at
    remove_reference :course_registrations, :trial_session, foreign_key: { to_table: :training_sessions }
  end
end
