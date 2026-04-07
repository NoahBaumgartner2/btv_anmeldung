class AddAttendanceFieldsToExportProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :export_profiles, :export_type,               :string,  default: "teilnehmerliste", null: false
    add_column :export_profiles, :date_range_type,           :string,  default: "custom"
    add_column :export_profiles, :date_from,                 :date
    add_column :export_profiles, :date_to,                   :date
    add_column :export_profiles, :date_column_format,        :string,  default: "%d.%m.%Y"
    add_column :export_profiles, :attendance_symbols,        :string,  default: "symbols"
    add_column :export_profiles, :include_canceled_sessions, :boolean, default: false
    add_column :export_profiles, :include_summary_columns,   :string,  array: true, default: []
    add_column :export_profiles, :sort_by,                   :string,  default: "last_name"
    add_column :export_profiles, :extra_empty_rows,          :integer, default: 0
  end
end
