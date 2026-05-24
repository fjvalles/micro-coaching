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

ActiveRecord::Schema[7.2].define(version: 2026_05_24_100000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "admin_users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_admin_users_on_unlock_token", unique: true
  end

  create_table "conversations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "participant_id", null: false
    t.integer "day_number"
    t.integer "moment", null: false
    t.integer "role", null: false
    t.text "body"
    t.string "whatsapp_message_id"
    t.string "whatsapp_template_name"
    t.text "prompt_used"
    t.string "model_used"
    t.integer "tokens_input"
    t.integer "tokens_output"
    t.text "error_message"
    t.datetime "sent_at"
    t.datetime "delivered_at"
    t.datetime "read_at"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "media_id"
    t.string "media_mime_type"
    t.integer "audio_duration_seconds"
    t.text "transcription"
    t.jsonb "voice_analysis", default: {}, null: false
    t.index ["discarded_at"], name: "index_conversations_on_discarded_at"
    t.index ["media_id"], name: "index_conversations_on_media_id", unique: true, where: "(media_id IS NOT NULL)"
    t.index ["moment"], name: "index_conversations_on_moment"
    t.index ["participant_id", "day_number"], name: "index_conversations_on_participant_id_and_day_number"
    t.index ["participant_id"], name: "index_conversations_on_participant_id"
    t.index ["whatsapp_message_id"], name: "index_conversations_on_whatsapp_message_id", unique: true, where: "(whatsapp_message_id IS NOT NULL)"
  end

  create_table "daily_reports", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "participant_id", null: false
    t.integer "day_number", null: false
    t.text "raw_text"
    t.text "ai_summary"
    t.text "ai_key_pattern"
    t.datetime "reported_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["participant_id", "day_number"], name: "index_daily_reports_on_participant_id_and_day_number"
    t.index ["participant_id"], name: "index_daily_reports_on_participant_id"
  end

  create_table "day_contents", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "day_number", null: false
    t.integer "phase", null: false
    t.string "title", null: false
    t.text "morning_template"
    t.text "iareto_text"
    t.text "checkin_questions"
    t.text "ai_system_prompt"
    t.string "template_name_whatsapp"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "program_id", null: false
    t.index ["program_id", "day_number"], name: "index_day_contents_on_program_id_and_day_number", unique: true
    t.index ["program_id"], name: "index_day_contents_on_program_id"
  end

  create_table "participants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "phone_e164", null: false
    t.string "email"
    t.integer "status", default: 0, null: false
    t.integer "current_day", default: 0, null: false
    t.datetime "enrolled_at"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.string "timezone", default: "America/Santiago", null: false
    t.text "initial_pattern"
    t.jsonb "energy_map", default: {}
    t.text "closing_manifesto"
    t.datetime "pending_checkin_at"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "program_id"
    t.string "company"
    t.string "role"
    t.index ["discarded_at"], name: "index_participants_on_discarded_at"
    t.index ["phone_e164"], name: "index_participants_on_phone_e164", unique: true
    t.index ["program_id"], name: "index_participants_on_program_id"
    t.index ["status"], name: "index_participants_on_status"
  end

  create_table "programs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.text "manifesto"
    t.integer "total_days", default: 14, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_programs_on_slug", unique: true
  end

  create_table "settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.text "value"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "value_type", default: "string", null: false
    t.string "category", default: "general", null: false
    t.index ["category"], name: "index_settings_on_category"
    t.index ["key"], name: "index_settings_on_key", unique: true
  end

  add_foreign_key "conversations", "participants"
  add_foreign_key "daily_reports", "participants"
  add_foreign_key "day_contents", "programs"
  add_foreign_key "participants", "programs"
end
