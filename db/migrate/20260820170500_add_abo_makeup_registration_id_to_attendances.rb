class AddAboMakeupRegistrationIdToAttendances < ActiveRecord::Migration[8.1]
  def change
    add_reference :attendances, :abo_makeup_registration, foreign_key: { to_table: :course_registrations }, null: true
  end
end
