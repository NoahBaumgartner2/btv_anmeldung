class AddRestrictedToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :restricted, :boolean, default: false, null: false
  end
end
