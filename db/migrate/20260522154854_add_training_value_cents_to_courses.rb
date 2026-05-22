class AddTrainingValueCentsToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :training_value_cents, :integer
  end
end
