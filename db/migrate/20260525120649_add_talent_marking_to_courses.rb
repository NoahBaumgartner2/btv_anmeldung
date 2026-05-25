class AddTalentMarkingToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :allows_talent_marking, :boolean, default: false, null: false
  end
end
