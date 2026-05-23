class FixTrainingSessionTimezoneOffset < ActiveRecord::Migration[8.1]
  def up
    # Nur Sessions VOR der Sommerzeit-Umstellung 2026 korrigieren.
    # Sommerzeit 2026 begann am 29. März 2026 um 02:00 Uhr.
    # Winterzeit-Sessions wurden mit UTC+0 statt UTC+1 gespeichert → +1h korrigieren.
    winter_cutoff = Time.utc(2026, 3, 29, 1, 0, 0) # 29. März 02:00 Zürich = 01:00 UTC

    TrainingSession.where("start_time < ?", winter_cutoff).find_each do |s|
      s.update_columns(
        start_time: s.start_time + 1.hour,
        end_time:   s.end_time ? s.end_time + 1.hour : nil
      )
    end
  end

  def down
    winter_cutoff = Time.utc(2026, 3, 29, 2, 0, 0) # nach Korrektur

    TrainingSession.where("start_time < ?", winter_cutoff).find_each do |s|
      s.update_columns(
        start_time: s.start_time - 1.hour,
        end_time:   s.end_time ? s.end_time - 1.hour : nil
      )
    end
  end
end
