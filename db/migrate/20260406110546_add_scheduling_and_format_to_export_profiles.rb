class AddSchedulingAndFormatToExportProfiles < ActiveRecord::Migration[8.1]
  def change
    add_column :export_profiles, :schedule,        :string,  default: "none"
    add_column :export_profiles, :recipient_email, :string
    add_column :export_profiles, :course_id,       :bigint
    add_column :export_profiles, :col_sep,         :string,  default: ";"
    add_column :export_profiles, :row_sep,         :string,  default: "\\n"
    add_column :export_profiles, :quote_char,      :string,  default: '"'
    add_column :export_profiles, :include_header,  :boolean, default: true
  end
end
