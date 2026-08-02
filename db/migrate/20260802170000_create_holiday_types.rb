class CreateHolidayTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :holiday_types do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :holiday_types, :name, unique: true
  end
end
