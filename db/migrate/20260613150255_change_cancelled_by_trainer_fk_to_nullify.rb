class ChangeCancelledByTrainerFkToNullify < ActiveRecord::Migration[8.1]
  def up
    remove_foreign_key :course_registrations, column: :cancelled_by_trainer_id
    add_foreign_key :course_registrations, :trainers,
                    column: :cancelled_by_trainer_id, on_delete: :nullify
  end

  def down
    remove_foreign_key :course_registrations, column: :cancelled_by_trainer_id
    add_foreign_key :course_registrations, :trainers,
                    column: :cancelled_by_trainer_id
  end
end
