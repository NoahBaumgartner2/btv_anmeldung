# Hält fest, welcher Betrag bestätigt wurde, was das System berechnet hat und warum es abweicht.
class AddRefundDetailsToCourseRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :course_registrations, :refund_amount_cents, :integer
    add_column :course_registrations, :refund_calculated_cents, :integer
    add_column :course_registrations, :refund_note, :text
  end
end
