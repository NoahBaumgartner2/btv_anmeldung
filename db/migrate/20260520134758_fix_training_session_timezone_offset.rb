class FixTrainingSessionTimezoneOffset < ActiveRecord::Migration[8.1]
  def up
    # Vor der Ausführung in der Rails Console prüfen:
    # TrainingSession.order(:start_time).first(3).map { |s| "#{s.start_time} / #{s.start_time.in_time_zone('Europe/Zurich')}" }
    #
    # Nur ausführen wenn start_time als "15:00 UTC" gespeichert war, aber "15:00 Zürich" gemeint war.
    # In diesem Fall -2h korrigieren:
    #
    # TrainingSession.find_each do |s|
    #   s.update_columns(
    #     start_time: s.start_time - 2.hours,
    #     end_time:   s.end_time ? s.end_time - 2.hours : nil
    #   )
    # end
  end

  def down; end
end
