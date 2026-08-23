class AddAllowsLateRegistrationDeductionToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :allows_late_registration_deduction, :boolean, default: true, null: false
  end
end
