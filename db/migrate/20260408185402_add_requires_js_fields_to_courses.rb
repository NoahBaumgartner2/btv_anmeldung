class AddRequiresJsFieldsToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :requires_js_person_number, :boolean, default: false, null: false
    add_column :courses, :requires_nationality, :boolean, default: false, null: false
    add_column :courses, :requires_mother_tongue, :boolean, default: false, null: false
    add_column :courses, :requires_zip_code, :boolean, default: false, null: false
    add_column :courses, :requires_city, :boolean, default: false, null: false
    add_column :courses, :requires_country, :boolean, default: false, null: false
    add_column :courses, :requires_street, :boolean, default: false, null: false
  end
end
