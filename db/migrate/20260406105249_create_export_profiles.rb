class CreateExportProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :export_profiles do |t|
      t.string  :name,    null: false
      t.string  :format,  null: false, default: "csv"
      t.string  :fields,  array: true, default: []

      t.timestamps
    end
  end
end
