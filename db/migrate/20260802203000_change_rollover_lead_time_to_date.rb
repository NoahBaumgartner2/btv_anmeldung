class ChangeRolloverLeadTimeToDate < ActiveRecord::Migration[8.1]
  def change
    remove_column :courses, :renewal_priority_weeks, :integer, default: 3
    remove_column :courses, :public_registration_weeks, :integer, default: 1
    add_column :courses, :renewal_priority_date, :date
    add_column :courses, :public_registration_days, :integer, default: 7
  end
end
