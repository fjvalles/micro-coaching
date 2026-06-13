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

ActiveRecord::Schema[7.2].define(version: 2026_06_13_120002) do
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

  create_table "coach_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "participant_id", null: false
    t.uuid "admin_user_id"
    t.integer "status", default: 0, null: false
    t.datetime "scheduled_at"
    t.integer "duration_minutes", default: 30, null: false
    t.string "meeting_url"
    t.text "notes"
    t.datetime "reminder_sent_at"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_user_id"], name: "index_coach_sessions_on_admin_user_id"
    t.index ["discarded_at"], name: "index_coach_sessions_on_discarded_at"
    t.index ["participant_id"], name: "index_coach_sessions_on_participant_id"
    t.index ["scheduled_at"], name: "index_coach_sessions_on_scheduled_at"
    t.index ["status"], name: "index_coach_sessions_on_status"
  end

  create_table "companies", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "coach_name"
    t.string "contact_email"
    t.boolean "active", default: true, null: false
    t.boolean "covers_membership", default: true, null: false
    t.text "notes"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_companies_on_discarded_at"
    t.index ["slug"], name: "index_companies_on_slug", unique: true
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

  create_table "enrollments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "participant_id", null: false
    t.uuid "program_id", null: false
    t.integer "cycle_number", default: 1, null: false
    t.integer "status", default: 0, null: false
    t.datetime "started_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["participant_id", "program_id", "cycle_number"], name: "index_enrollments_on_participant_program_cycle", unique: true
    t.index ["participant_id", "status"], name: "index_enrollments_on_participant_id_and_status"
    t.index ["participant_id"], name: "index_enrollments_on_participant_id"
    t.index ["program_id"], name: "index_enrollments_on_program_id"
  end

  create_table "methodology_insights", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "scope", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "generated_at", null: false
    t.uuid "program_id"
    t.date "window_start"
    t.date "window_end"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["program_id", "scope"], name: "index_methodology_insights_on_program_id_and_scope"
    t.index ["scope", "generated_at"], name: "index_methodology_insights_on_scope_and_generated_at", order: { generated_at: :desc }
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
    t.string "response_mode"
    t.uuid "company_id"
    t.text "coach_notes"
    t.text "focus_hint"
    t.text "ai_summary"
    t.datetime "ai_summary_updated_at"
    t.index ["company_id"], name: "index_participants_on_company_id"
    t.index ["discarded_at"], name: "index_participants_on_discarded_at"
    t.index ["phone_e164"], name: "index_participants_on_phone_e164", unique: true
    t.index ["program_id"], name: "index_participants_on_program_id"
    t.index ["status"], name: "index_participants_on_status"
  end

  create_table "payments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "participant_id"
    t.uuid "company_id"
    t.uuid "program_id"
    t.integer "amount", default: 0, null: false
    t.string "currency", default: "CLP", null: false
    t.integer "status", default: 0, null: false
    t.string "buy_order", null: false
    t.string "session_id"
    t.string "token"
    t.string "authorization_code"
    t.string "payment_type_code"
    t.integer "response_code"
    t.integer "installments"
    t.string "card_last4"
    t.string "payer_email"
    t.integer "commission_amount", default: 0, null: false
    t.integer "net_amount", default: 0, null: false
    t.jsonb "raw_response", default: {}, null: false
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "subscription_id"
    t.index ["buy_order"], name: "index_payments_on_buy_order", unique: true
    t.index ["company_id"], name: "index_payments_on_company_id"
    t.index ["paid_at"], name: "index_payments_on_paid_at"
    t.index ["participant_id"], name: "index_payments_on_participant_id"
    t.index ["program_id"], name: "index_payments_on_program_id"
    t.index ["status"], name: "index_payments_on_status"
    t.index ["subscription_id"], name: "index_payments_on_subscription_id"
    t.index ["token"], name: "index_payments_on_token"
  end

  create_table "pending_responses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "participant_id", null: false
    t.uuid "conversation_id"
    t.uuid "approved_by_id"
    t.string "status", default: "pending", null: false
    t.string "mode", null: false
    t.string "moment", null: false
    t.integer "day_number"
    t.text "draft_body", null: false
    t.text "original_body"
    t.text "prompt_used"
    t.string "model_used"
    t.integer "tokens_input"
    t.integer "tokens_output"
    t.string "template_name"
    t.jsonb "template_variables", default: [], null: false
    t.string "delivery_kind", default: "text", null: false
    t.text "rejection_reason"
    t.datetime "acted_at"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_pending_responses_on_approved_by_id"
    t.index ["conversation_id"], name: "index_pending_responses_on_conversation_id"
    t.index ["discarded_at"], name: "index_pending_responses_on_discarded_at"
    t.index ["participant_id", "status"], name: "index_pending_responses_on_participant_id_and_status"
    t.index ["participant_id"], name: "index_pending_responses_on_participant_id"
    t.index ["status"], name: "index_pending_responses_on_status"
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
    t.string "response_mode"
    t.uuid "company_id"
    t.uuid "next_program_id"
    t.index ["company_id"], name: "index_programs_on_company_id"
    t.index ["next_program_id"], name: "index_programs_on_next_program_id"
    t.index ["slug"], name: "index_programs_on_slug", unique: true
  end

  create_table "prompt_analyses", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "prompt_template_id", null: false
    t.uuid "prompt_version_id"
    t.integer "executions_sampled", default: 0, null: false
    t.jsonb "findings", default: {}, null: false
    t.text "suggested_body"
    t.text "rationale"
    t.string "model_used"
    t.integer "tokens_input"
    t.integer "tokens_output"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_prompt_analyses_on_created_at"
    t.index ["prompt_template_id"], name: "index_prompt_analyses_on_prompt_template_id"
    t.index ["prompt_version_id"], name: "index_prompt_analyses_on_prompt_version_id"
  end

  create_table "prompt_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "prompt_template_id", null: false
    t.uuid "prompt_version_id", null: false
    t.uuid "participant_id"
    t.uuid "conversation_id"
    t.integer "day_number"
    t.string "moment"
    t.jsonb "rendered_messages", default: [], null: false
    t.text "output_body"
    t.string "model_used"
    t.integer "tokens_input"
    t.integer "tokens_output"
    t.integer "latency_ms"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id"], name: "index_prompt_executions_on_conversation_id"
    t.index ["created_at"], name: "index_prompt_executions_on_created_at"
    t.index ["participant_id"], name: "index_prompt_executions_on_participant_id"
    t.index ["prompt_template_id", "day_number"], name: "index_prompt_executions_on_prompt_template_id_and_day_number"
    t.index ["prompt_template_id"], name: "index_prompt_executions_on_prompt_template_id"
    t.index ["prompt_version_id"], name: "index_prompt_executions_on_prompt_version_id"
  end

  create_table "prompt_templates", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.uuid "program_id"
    t.integer "day_number"
    t.string "name", null: false
    t.text "description"
    t.text "current_body", default: "", null: false
    t.integer "current_version", default: 0, null: false
    t.string "source", default: "service", null: false
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_prompt_templates_on_discarded_at"
    t.index ["key", "program_id", "day_number"], name: "idx_prompt_templates_unique", unique: true
    t.index ["program_id"], name: "index_prompt_templates_on_program_id"
  end

  create_table "prompt_versions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "prompt_template_id", null: false
    t.uuid "author_id"
    t.integer "version", null: false
    t.text "body", null: false
    t.text "change_note"
    t.string "origin", default: "service", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_prompt_versions_on_author_id"
    t.index ["prompt_template_id", "version"], name: "index_prompt_versions_on_prompt_template_id_and_version", unique: true
    t.index ["prompt_template_id"], name: "index_prompt_versions_on_prompt_template_id"
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

  create_table "skill_detections", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "participant_id", null: false
    t.uuid "conversation_id", null: false
    t.uuid "skill_id", null: false
    t.float "confidence"
    t.string "source"
    t.datetime "detected_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "skill_id"], name: "index_skill_detections_on_conversation_id_and_skill_id", unique: true
    t.index ["conversation_id"], name: "index_skill_detections_on_conversation_id"
    t.index ["participant_id", "detected_at"], name: "index_skill_detections_on_participant_id_and_detected_at", order: { detected_at: :desc }
    t.index ["participant_id"], name: "index_skill_detections_on_participant_id"
    t.index ["skill_id"], name: "index_skill_detections_on_skill_id"
  end

  create_table "skills", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "slug", null: false
    t.string "name", null: false
    t.integer "position"
    t.text "definition"
    t.text "importance"
    t.text "trap"
    t.text "one_liner"
    t.jsonb "signals", default: [], null: false
    t.jsonb "practices", default: [], null: false
    t.jsonb "gestures", default: [], null: false
    t.jsonb "exercises", default: [], null: false
    t.jsonb "reflection_questions", default: [], null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_skills_on_position"
    t.index ["slug"], name: "index_skills_on_slug", unique: true
  end

  create_table "subscriptions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "participant_id"
    t.uuid "company_id"
    t.uuid "program_id"
    t.integer "status", default: 0, null: false
    t.string "plan"
    t.integer "amount_clp", default: 0, null: false
    t.string "tbk_user"
    t.string "tbk_username"
    t.string "card_last4"
    t.integer "billing_interval_days", default: 30, null: false
    t.datetime "next_billing_at"
    t.integer "billing_cycle_count", default: 0, null: false
    t.datetime "last_billed_at"
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "started_at"
    t.datetime "canceled_at"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_subscriptions_on_company_id"
    t.index ["discarded_at"], name: "index_subscriptions_on_discarded_at"
    t.index ["next_billing_at"], name: "index_subscriptions_on_next_billing_at"
    t.index ["participant_id"], name: "index_subscriptions_on_participant_id"
    t.index ["program_id"], name: "index_subscriptions_on_program_id"
    t.index ["status"], name: "index_subscriptions_on_status"
    t.index ["tbk_user"], name: "index_subscriptions_on_tbk_user"
  end

  create_table "unknown_inbounds", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "phone"
    t.string "wamid"
    t.string "message_type"
    t.string "body_preview"
    t.datetime "received_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["received_at"], name: "index_unknown_inbounds_on_received_at"
    t.index ["wamid"], name: "index_unknown_inbounds_on_wamid", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.string "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.text "object_changes"
    t.string "source"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "coach_sessions", "admin_users"
  add_foreign_key "coach_sessions", "participants"
  add_foreign_key "conversations", "participants"
  add_foreign_key "daily_reports", "participants"
  add_foreign_key "day_contents", "programs"
  add_foreign_key "enrollments", "participants"
  add_foreign_key "enrollments", "programs"
  add_foreign_key "methodology_insights", "programs"
  add_foreign_key "participants", "companies"
  add_foreign_key "participants", "programs"
  add_foreign_key "payments", "companies"
  add_foreign_key "payments", "participants"
  add_foreign_key "payments", "programs"
  add_foreign_key "payments", "subscriptions"
  add_foreign_key "pending_responses", "admin_users", column: "approved_by_id"
  add_foreign_key "pending_responses", "conversations"
  add_foreign_key "pending_responses", "participants"
  add_foreign_key "programs", "companies"
  add_foreign_key "programs", "programs", column: "next_program_id"
  add_foreign_key "prompt_analyses", "prompt_templates"
  add_foreign_key "prompt_analyses", "prompt_versions"
  add_foreign_key "prompt_executions", "conversations"
  add_foreign_key "prompt_executions", "participants"
  add_foreign_key "prompt_executions", "prompt_templates"
  add_foreign_key "prompt_executions", "prompt_versions"
  add_foreign_key "prompt_templates", "programs"
  add_foreign_key "prompt_versions", "admin_users", column: "author_id"
  add_foreign_key "prompt_versions", "prompt_templates"
  add_foreign_key "skill_detections", "conversations"
  add_foreign_key "skill_detections", "participants"
  add_foreign_key "skill_detections", "skills"
  add_foreign_key "subscriptions", "companies"
  add_foreign_key "subscriptions", "participants"
  add_foreign_key "subscriptions", "programs"
end
