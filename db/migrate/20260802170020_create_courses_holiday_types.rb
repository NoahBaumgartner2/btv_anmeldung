class CreateCoursesHolidayTypes < ActiveRecord::Migration[8.1]
  # Join-Tabelle: welche Ferien-Typen soll die automatische Trainings-
  # Generierung (bei Erstellung & Rollover) für diesen Kurs überspringen.
  def change
    create_table :courses_holiday_types, id: false do |t|
      t.bigint :course_id, null: false
      t.bigint :holiday_type_id, null: false
    end
    add_index :courses_holiday_types, [ :course_id, :holiday_type_id ], unique: true, name: "index_courses_holiday_types_on_course_and_type"
    add_index :courses_holiday_types, :holiday_type_id
    add_foreign_key :courses_holiday_types, :courses
    add_foreign_key :courses_holiday_types, :holiday_types
  end
end
