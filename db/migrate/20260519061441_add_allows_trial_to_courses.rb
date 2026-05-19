class AddAllowsTrialToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :allows_trial, :boolean, default: false, null: false
  end
end
