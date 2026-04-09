class AddAgeLimitsToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :min_age, :integer
    add_column :courses, :max_age, :integer
  end
end
