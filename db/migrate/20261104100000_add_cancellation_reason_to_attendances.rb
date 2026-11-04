# Gesetzt, wenn das Training nur für diese Person abgesagt wurde (Status "abgemeldet").
class AddCancellationReasonToAttendances < ActiveRecord::Migration[8.1]
  def change
    add_column :attendances, :cancellation_reason, :text
  end
end
