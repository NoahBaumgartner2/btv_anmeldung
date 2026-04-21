class AddCategoryToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :category, :string
  end
end
