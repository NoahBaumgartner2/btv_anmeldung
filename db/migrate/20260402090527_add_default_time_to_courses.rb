class AddDefaultTimeToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :default_start_hour, :integer
    add_column :courses, :default_start_minute, :integer
    add_column :courses, :default_end_hour, :integer
    add_column :courses, :default_end_minute, :integer
  end
end
