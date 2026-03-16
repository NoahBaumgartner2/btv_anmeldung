# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_16_125646) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "course_registrations", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.bigint "registration_id", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_course_registrations_on_course_id"
    t.index ["registration_id"], name: "index_course_registrations_on_registration_id"
  end

  create_table "courses", force: :cascade do |t|
    t.boolean "allows_holiday_deduction"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "end_date"
    t.boolean "has_payment"
    t.boolean "has_ticketing"
    t.string "location"
    t.string "registration_type"
    t.datetime "start_date"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "registrations", force: :cascade do |t|
    t.string "ahv_number"
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.string "email"
    t.string "first_name"
    t.string "gender"
    t.string "last_name"
    t.string "phone_number"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "course_registrations", "courses"
  add_foreign_key "course_registrations", "registrations"
end
