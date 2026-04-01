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

ActiveRecord::Schema[8.1].define(version: 2026_03_30_203422) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "attendances", force: :cascade do |t|
    t.bigint "course_registration_id", null: false
    t.datetime "created_at", null: false
    t.string "status"
    t.bigint "training_session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["course_registration_id"], name: "index_attendances_on_course_registration_id"
    t.index ["training_session_id"], name: "index_attendances_on_training_session_id"
  end

  create_table "course_registrations", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.boolean "holiday_deduction_claimed"
    t.bigint "participant_id", null: false
    t.boolean "payment_cleared"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_course_registrations_on_course_id"
    t.index ["participant_id"], name: "index_course_registrations_on_participant_id"
  end

  create_table "course_trainers", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.bigint "trainer_id", null: false
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_course_trainers_on_course_id"
    t.index ["trainer_id"], name: "index_course_trainers_on_trainer_id"
  end

  create_table "courses", force: :cascade do |t|
    t.boolean "allows_holiday_deduction"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "end_date"
    t.boolean "has_payment"
    t.boolean "has_ticketing"
    t.string "location"
    t.integer "max_participants"
    t.string "registration_mode"
    t.string "registration_type"
    t.datetime "start_date"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "holidays", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "end_date"
    t.date "start_date"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "participants", force: :cascade do |t|
    t.string "ahv_number"
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.string "email"
    t.string "first_name"
    t.string "gender"
    t.string "last_name"
    t.string "phone_number"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_participants_on_user_id"
  end

  create_table "trainers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_trainers_on_user_id"
  end

  create_table "training_sessions", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.datetime "end_time"
    t.boolean "is_canceled"
    t.datetime "start_time"
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_training_sessions_on_course_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "attendances", "course_registrations"
  add_foreign_key "attendances", "training_sessions"
  add_foreign_key "course_registrations", "courses"
  add_foreign_key "course_registrations", "participants"
  add_foreign_key "course_trainers", "courses"
  add_foreign_key "course_trainers", "trainers"
  add_foreign_key "participants", "users"
  add_foreign_key "trainers", "users"
  add_foreign_key "training_sessions", "courses"
end
