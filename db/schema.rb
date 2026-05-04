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

ActiveRecord::Schema[8.1].define(version: 2026_05_12_010001) do
  create_table "activity_logs", force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.text "details"
    t.string "ip_address"
    t.integer "resource_id"
    t.string "resource_type"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["action"], name: "index_activity_logs_on_action"
    t.index ["created_at"], name: "index_activity_logs_on_created_at"
    t.index ["user_id"], name: "index_activity_logs_on_user_id"
  end

  create_table "appointments", force: :cascade do |t|
    t.string "ai_model_used", default: "rule_based_fallback"
    t.text "ai_reasoning"
    t.string "approval_status", default: "pending"
    t.integer "approved_by"
    t.datetime "created_at", null: false
    t.text "diagnosis"
    t.integer "doctor_id"
    t.text "notes"
    t.string "original_priority_level"
    t.integer "original_priority_score"
    t.integer "patient_id", null: false
    t.datetime "preferred_date"
    t.string "priority_level"
    t.integer "priority_score"
    t.datetime "scheduled_at"
    t.string "severity"
    t.string "status"
    t.text "symptoms"
    t.datetime "updated_at", null: false
    t.index ["approval_status"], name: "index_appointments_on_approval_status"
    t.index ["doctor_id"], name: "index_appointments_on_doctor_id"
    t.index ["patient_id"], name: "index_appointments_on_patient_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "message"
    t.string "notification_type"
    t.boolean "read", default: false
    t.integer "reference_id"
    t.string "reference_type"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["notification_type"], name: "index_notifications_on_notification_type"
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "patients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.string "name"
    t.string "phone"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_patients_on_user_id"
  end

  create_table "system_configs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "updated_by"
    t.string "value", null: false
    t.index ["key"], name: "index_system_configs_on_key", unique: true
  end

  create_table "time_slots", force: :cascade do |t|
    t.integer "appointment_id"
    t.datetime "created_at", null: false
    t.integer "doctor_id", null: false
    t.datetime "end_time", null: false
    t.datetime "start_time", null: false
    t.string "status", default: "available"
    t.datetime "updated_at", null: false
    t.index ["appointment_id"], name: "index_time_slots_on_appointment_id"
    t.index ["doctor_id", "start_time", "end_time"], name: "index_time_slots_on_doctor_and_time"
    t.index ["doctor_id"], name: "index_time_slots_on_doctor_id"
    t.index ["status"], name: "index_time_slots_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.string "email"
    t.boolean "email_verified", default: false
    t.datetime "last_login_at"
    t.string "name"
    t.string "otp_code"
    t.datetime "otp_expires_at"
    t.string "password_digest"
    t.string "phone"
    t.integer "role"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "activity_logs", "users"
  add_foreign_key "appointments", "patients"
  add_foreign_key "notifications", "users"
  add_foreign_key "patients", "users"
  add_foreign_key "time_slots", "appointments"
end
