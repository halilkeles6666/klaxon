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

ActiveRecord::Schema[8.0].define(version: 2026_10_20_120000) do
  create_table "alerts", force: :cascade do |t|
    t.integer "incident_id", null: false
    t.string "summary", null: false
    t.string "source"
    t.boolean "deduplicated", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["incident_id"], name: "index_alerts_on_incident_id"
  end

  create_table "comments", force: :cascade do |t|
    t.integer "ticket_id", null: false
    t.integer "author_id"
    t.text "body", null: false
    t.boolean "internal", default: false, null: false
    t.string "via", default: "agent", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_comments_on_author_id"
    t.index ["ticket_id"], name: "index_comments_on_ticket_id"
  end

  create_table "escalation_policies", force: :cascade do |t|
    t.string "name", null: false
    t.integer "ack_timeout_minutes", default: 15, null: false
    t.integer "max_level", default: 3, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_escalation_policies_on_name", unique: true
  end

  create_table "incident_events", force: :cascade do |t|
    t.integer "incident_id", null: false
    t.integer "actor_id"
    t.string "kind", null: false
    t.text "detail"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_incident_events_on_actor_id"
    t.index ["incident_id", "created_at"], name: "index_incident_events_on_incident_id_and_created_at"
    t.index ["incident_id"], name: "index_incident_events_on_incident_id"
  end

  create_table "incidents", force: :cascade do |t|
    t.string "reference", null: false
    t.string "title", null: false
    t.string "status", default: "triggered", null: false
    t.string "urgency", default: "high", null: false
    t.string "dedup_key", null: false
    t.integer "service_id", null: false
    t.integer "acknowledged_by_id"
    t.integer "escalation_level", default: 1, null: false
    t.datetime "triggered_at", null: false
    t.datetime "acknowledged_at"
    t.datetime "resolved_at"
    t.datetime "escalated_at"
    t.integer "alerts_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "severity"
    t.string "agent_action"
    t.float "agent_confidence"
    t.boolean "auto_resolved", default: false, null: false
    t.integer "resolution_attempts", default: 0, null: false
    t.string "root_cause_action"
    t.boolean "simulated", default: false, null: false
    t.integer "paged_user_id"
    t.boolean "needs_human", default: false, null: false
    t.index ["acknowledged_by_id"], name: "index_incidents_on_acknowledged_by_id"
    t.index ["paged_user_id"], name: "index_incidents_on_paged_user_id"
    t.index ["reference"], name: "index_incidents_on_reference", unique: true
    t.index ["service_id", "dedup_key", "status"], name: "index_incidents_on_service_id_and_dedup_key_and_status"
    t.index ["service_id"], name: "index_incidents_on_service_id"
    t.index ["status"], name: "index_incidents_on_status"
  end

  create_table "on_call_shifts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["starts_at", "ends_at"], name: "index_on_call_shifts_on_starts_at_and_ends_at"
    t.index ["user_id"], name: "index_on_call_shifts_on_user_id"
  end

  create_table "services", force: :cascade do |t|
    t.string "name", null: false
    t.string "routing_key", null: false
    t.integer "escalation_policy_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["escalation_policy_id"], name: "index_services_on_escalation_policy_id"
    t.index ["routing_key"], name: "index_services_on_routing_key", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "sla_policies", force: :cascade do |t|
    t.string "name", null: false
    t.string "priority", null: false
    t.integer "first_response_minutes", null: false
    t.integer "resolution_minutes", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["priority"], name: "index_sla_policies_on_priority", unique: true
  end

  create_table "tickets", force: :cascade do |t|
    t.string "reference", null: false
    t.string "subject", null: false
    t.text "description"
    t.string "status", default: "new", null: false
    t.string "priority", default: "normal", null: false
    t.string "requester_name"
    t.string "requester_email", null: false
    t.integer "assignee_id"
    t.integer "sla_policy_id"
    t.datetime "first_response_due_at"
    t.datetime "resolution_due_at"
    t.datetime "first_responded_at"
    t.datetime "pending_since"
    t.datetime "solved_at"
    t.datetime "closed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_tickets_on_assignee_id"
    t.index ["reference"], name: "index_tickets_on_reference", unique: true
    t.index ["sla_policy_id"], name: "index_tickets_on_sla_policy_id"
    t.index ["status"], name: "index_tickets_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.string "name", default: "", null: false
    t.string "role", default: "agent", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "telegram_chat_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "alerts", "incidents"
  add_foreign_key "comments", "tickets"
  add_foreign_key "comments", "users", column: "author_id"
  add_foreign_key "incident_events", "incidents"
  add_foreign_key "incident_events", "users", column: "actor_id"
  add_foreign_key "incidents", "services"
  add_foreign_key "incidents", "users", column: "acknowledged_by_id"
  add_foreign_key "incidents", "users", column: "paged_user_id"
  add_foreign_key "on_call_shifts", "users"
  add_foreign_key "services", "escalation_policies"
  add_foreign_key "sessions", "users"
  add_foreign_key "tickets", "sla_policies"
  add_foreign_key "tickets", "users", column: "assignee_id"
end
