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

ActiveRecord::Schema[8.1].define(version: 2026_05_15_210357) do
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
    t.string "contact_city"
    t.string "contact_email"
    t.string "contact_phone"
    t.string "contact_street"
    t.string "contact_website"
    t.string "contact_zip"
    t.datetime "created_at", null: false
    t.string "hosting_country"
    t.string "hosting_provider"
    t.string "legal_form"
    t.string "payment_provider", default: "SumUp"
    t.string "primary_color"
    t.string "privacy_officer_email"
    t.string "privacy_officer_name"
    t.string "responsible_function"
    t.string "responsible_name"
    t.string "secondary_color"
    t.string "smtp_provider"
    t.datetime "updated_at", null: false
  end

  create_table "course_registrations", force: :cascade do |t|
    t.integer "abo_entries_total"
    t.integer "abo_entries_used", default: 0
    t.boolean "cancellation_notify_admin", default: false, null: false
    t.text "cancellation_reason"
    t.datetime "cancelled_at"
    t.bigint "cancelled_by_trainer_id"
    t.bigint "course_id", null: false
    t.datetime "created_at", null: false
    t.boolean "holiday_deduction_claimed"
    t.bigint "participant_id", null: false
    t.boolean "payment_cleared"
    t.datetime "payment_expires_at"
    t.integer "payment_reminder_count", default: 0, null: false
    t.string "status"
    t.string "sumup_checkout_id"
    t.string "sumup_transaction_id"
    t.bigint "training_session_id"
    t.datetime "updated_at", null: false
    t.index ["cancelled_by_trainer_id"], name: "index_course_registrations_on_cancelled_by_trainer_id"
    t.index ["course_id"], name: "index_course_registrations_on_course_id"
    t.index ["participant_id"], name: "index_course_registrations_on_participant_id"
    t.index ["sumup_checkout_id"], name: "index_course_registrations_on_sumup_checkout_id"
    t.index ["sumup_transaction_id"], name: "index_course_registrations_on_sumup_transaction_id"
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
    t.integer "abo_size"
    t.boolean "allows_holiday_deduction"
    t.string "category"
    t.datetime "created_at", null: false
    t.integer "default_end_hour"
    t.integer "default_end_minute"
    t.integer "default_start_hour"
    t.integer "default_start_minute"
    t.text "description"
    t.datetime "end_date"
    t.boolean "has_payment"
    t.boolean "has_ticketing"
    t.boolean "is_js_training", default: false, null: false
    t.string "location"
    t.string "location_address"
    t.integer "max_age"
    t.integer "max_participants"
    t.integer "min_age"
    t.string "payment_methods", default: ["card"], null: false, array: true
    t.integer "price_cents"
    t.string "registration_mode"
    t.string "registration_type"
    t.boolean "requires_ahv_number", default: false, null: false
    t.boolean "requires_city", default: false, null: false
    t.boolean "requires_country", default: false, null: false
    t.boolean "requires_js_person_number", default: false, null: false
    t.boolean "requires_mother_tongue", default: false, null: false
    t.boolean "requires_nationality", default: false, null: false
    t.boolean "requires_street", default: false, null: false
    t.boolean "requires_zip_code", default: false, null: false
    t.datetime "start_date"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "export_profiles", force: :cascade do |t|
    t.string "attendance_symbols", default: "symbols"
    t.string "col_sep", default: ";"
    t.bigint "course_id"
    t.datetime "created_at", null: false
    t.string "date_column_format", default: "%d.%m.%Y"
    t.date "date_from"
    t.string "date_range_type", default: "custom"
    t.date "date_to"
    t.string "export_type", default: "teilnehmerliste", null: false
    t.integer "extra_empty_rows", default: 0
    t.string "fields", default: [], array: true
    t.string "format", default: "csv", null: false
    t.boolean "include_canceled_sessions", default: false
    t.boolean "include_header", default: true
    t.string "include_summary_columns", default: [], array: true
    t.string "name", null: false
    t.string "quote_char", default: "\""
    t.string "recipient_email"
    t.string "row_sep", default: "\\n"
    t.string "schedule", default: "none"
    t.string "sort_by", default: "last_name"
    t.datetime "updated_at", null: false
  end

  create_table "holidays", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "end_date"
    t.date "start_date"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "infomaniak_settings", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.text "api_token_encrypted"
    t.string "base_url"
    t.datetime "created_at", null: false
    t.string "mailing_list_id"
    t.datetime "updated_at", null: false
  end

  create_table "mail_settings", force: :cascade do |t|
    t.string "app_host"
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
    t.string "unsubscribe_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_newsletter_subscribers_on_email", unique: true
    t.index ["unsubscribe_token"], name: "index_newsletter_subscribers_on_unsubscribe_token", unique: true
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
    t.string "city"
    t.string "country", default: "CH"
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.string "first_name"
    t.string "gender"
    t.string "house_number"
    t.string "js_person_number"
    t.string "last_name"
    t.string "mother_tongue", default: "DE"
    t.string "nationality", default: "CH"
    t.string "phone_number"
    t.string "street"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "zip_code"
    t.index ["first_name", "last_name", "date_of_birth", "user_id"], name: "index_participants_unique_per_user", unique: true
    t.index ["user_id"], name: "index_participants_on_user_id"
  end

  create_table "payment_settings", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "chf"
    t.text "sumup_access_token_encrypted"
    t.string "sumup_api_key"
    t.string "sumup_merchant_code"
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
    t.datetime "privacy_accepted_at"
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
  add_foreign_key "course_registrations", "trainers", column: "cancelled_by_trainer_id"
  add_foreign_key "course_registrations", "training_sessions"
  add_foreign_key "course_trainers", "courses"
  add_foreign_key "course_trainers", "trainers"
  add_foreign_key "participants", "users"
  add_foreign_key "trainers", "users"
  add_foreign_key "training_sessions", "courses"
end
