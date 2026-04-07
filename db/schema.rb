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

ActiveRecord::Schema[8.1].define(version: 2026_04_07_123227) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "attendances", force: :cascade do |t|
    t.bigint "course_registration_id", null: false
    t.datetime "created_at", null: false
    t.string "status"
    t.bigint "training_session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["course_registration_id"], name: "index_attendances_on_course_registration_id"
    t.index ["training_session_id"], name: "index_attendances_on_training_session_id"
  end

  create_table "club_settings", force: :cascade do |t|
    t.string "club_name"
    t.datetime "created_at", null: false
    t.string "primary_color"
    t.string "secondary_color"
    t.datetime "updated_at", null: false
  end

  create_table "course_registrations", force: :cascade do |t|
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.boolean "holiday_deduction_claimed"
    t.bigint "participant_id", null: false
    t.boolean "payment_cleared"
    t.string "status"
    t.string "stripe_payment_intent_id"
    t.string "stripe_session_id"
    t.bigint "training_session_id"
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_course_registrations_on_course_id"
    t.index ["participant_id"], name: "index_course_registrations_on_participant_id"
    t.index ["stripe_payment_intent_id"], name: "index_course_registrations_on_stripe_payment_intent_id"
    t.index ["stripe_session_id"], name: "index_course_registrations_on_stripe_session_id"
    t.index ["training_session_id"], name: "index_course_registrations_on_training_session_id"
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
    t.integer "default_end_hour"
    t.integer "default_end_minute"
    t.integer "default_start_hour"
    t.integer "default_start_minute"
    t.text "description"
    t.datetime "end_date"
    t.boolean "has_payment"
    t.boolean "has_ticketing"
    t.string "location"
    t.integer "max_participants"
    t.string "payment_methods", default: ["card"], null: false, array: true
    t.integer "price_cents"
    t.string "registration_mode"
    t.string "registration_type"
    t.boolean "requires_ahv_number", default: false, null: false
    t.datetime "start_date"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "export_profiles", force: :cascade do |t|
    t.string "col_sep", default: ";"
    t.bigint "course_id"
    t.datetime "created_at", null: false
    t.string "fields", default: [], array: true
    t.string "format", default: "csv", null: false
    t.boolean "include_header", default: true
    t.string "name", null: false
    t.string "quote_char", default: "\""
    t.string "recipient_email"
    t.string "row_sep", default: "\\n"
    t.string "schedule", default: "none"
    t.datetime "updated_at", null: false
  end

  create_table "holidays", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "end_date"
    t.date "start_date"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "mail_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "smtp_authentication", default: "plain"
    t.boolean "smtp_enable_starttls", default: true, null: false
    t.string "smtp_from_address"
    t.string "smtp_from_name"
    t.string "smtp_host"
    t.text "smtp_password_encrypted"
    t.integer "smtp_port", default: 587
    t.string "smtp_username"
    t.datetime "updated_at", null: false
  end

  create_table "newsletter_subscribers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.string "source", default: "manual"
    t.string "status", default: "subscribed", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_newsletter_subscribers_on_email", unique: true
  end

  create_table "newsletters", force: :cascade do |t|
    t.text "body_html"
    t.datetime "created_at", null: false
    t.integer "recipients_count"
    t.datetime "sent_at"
    t.string "status"
    t.string "subject"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "participants", force: :cascade do |t|
    t.string "ahv_number"
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.string "first_name"
    t.string "gender"
    t.string "last_name"
    t.string "phone_number"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["first_name", "last_name", "date_of_birth", "user_id"], name: "index_participants_unique_per_user", unique: true
    t.index ["user_id"], name: "index_participants_on_user_id"
  end

  create_table "payment_settings", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "chf"
    t.string "stripe_publishable_key"
    t.text "stripe_secret_key_encrypted"
    t.text "stripe_webhook_secret_encrypted"
    t.datetime "updated_at", null: false
  end

  create_table "trainers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_trainers_on_user_id"
  end

  create_table "training_sessions", force: :cascade do |t|
    t.datetime "admin_notified_at"
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.datetime "end_time"
    t.boolean "is_canceled"
    t.datetime "start_time"
    t.datetime "trainer_reminded_at"
    t.datetime "updated_at", null: false
    t.index ["course_id"], name: "index_training_sessions_on_course_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "locked_at"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "unconfirmed_email"
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "attendances", "course_registrations"
  add_foreign_key "attendances", "training_sessions"
  add_foreign_key "course_registrations", "courses"
  add_foreign_key "course_registrations", "participants"
  add_foreign_key "course_registrations", "training_sessions"
  add_foreign_key "course_trainers", "courses"
  add_foreign_key "course_trainers", "trainers"
  add_foreign_key "participants", "users"
  add_foreign_key "trainers", "users"
  add_foreign_key "training_sessions", "courses"
end
