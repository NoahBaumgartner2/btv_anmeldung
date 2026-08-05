class MoveRenewalPriorityDateToTerms < ActiveRecord::Migration[8.1]
  def change
    add_column :terms, :priority_registration_date, :date
    remove_column :courses, :renewal_priority_date, :date
  end
end
