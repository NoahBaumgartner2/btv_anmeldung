class AddIsJsTrainingToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :is_js_training, :boolean, default: false, null: false
  end
end
