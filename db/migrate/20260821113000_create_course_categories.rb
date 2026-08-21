class CreateCourseCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :course_categories do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :course_categories, :name, unique: true
  end
end
