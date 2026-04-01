class AddModeAndCapacityToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :registration_mode, :string
    add_column :courses, :max_participants, :integer
  end
end
