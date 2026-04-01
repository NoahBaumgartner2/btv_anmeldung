class AddRequiredFieldsToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :requires_ahv_number, :boolean, default: false, null: false
  end
end
