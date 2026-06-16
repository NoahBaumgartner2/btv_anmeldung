class AddAboSourceToCourseRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :course_registrations, :abo_source_registration_id, :bigint, null: true
    add_index  :course_registrations, :abo_source_registration_id
    add_foreign_key :course_registrations, :course_registrations,
                    column: :abo_source_registration_id,
                    on_delete: :nullify
  end
end
