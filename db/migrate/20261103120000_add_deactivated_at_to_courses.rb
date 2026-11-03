class AddDeactivatedAtToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :deactivated_at, :datetime
  end
end
