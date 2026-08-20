class AddGrantsAboMakeupEntryToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :grants_abo_makeup_entry, :boolean, default: false, null: false
  end
end
