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

ActiveRecord::Schema[8.1].define(version: 2026_02_21_000000) do
  create_table "account_transactions", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "account_reference", null: false
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.string "direction", null: false
    t.bigint "posting_batch_id", null: false
    t.integer "running_balance_cents"
    t.bigint "teller_transaction_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_reference"], name: "index_account_transactions_on_account_reference"
    t.index ["direction"], name: "index_account_transactions_on_direction"
    t.index ["posting_batch_id"], name: "index_account_transactions_on_posting_batch_id"
    t.index ["teller_transaction_id"], name: "index_account_transactions_on_teller_transaction_id"
  end

  create_table "audit_events", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "actor_user_id"
    t.bigint "auditable_id"
    t.string "auditable_type"
    t.bigint "branch_id"
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.text "metadata", size: :long, collation: "utf8mb4_bin"
    t.datetime "occurred_at", null: false
    t.bigint "teller_session_id"
    t.datetime "updated_at", null: false
    t.bigint "workstation_id"
    t.index ["actor_user_id"], name: "index_audit_events_on_actor_user_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_events_on_auditable"
    t.index ["branch_id"], name: "index_audit_events_on_branch_id"
    t.index ["event_type"], name: "index_audit_events_on_event_type"
    t.index ["occurred_at"], name: "index_audit_events_on_occurred_at"
    t.index ["teller_session_id"], name: "index_audit_events_on_teller_session_id"
    t.index ["workstation_id"], name: "index_audit_events_on_workstation_id"
    t.check_constraint "json_valid(`metadata`)", name: "metadata"
  end

  create_table "branches", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_branches_on_code", unique: true
  end

  create_table "cash_location_assignments", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "assigned_at", null: false
    t.bigint "cash_location_id", null: false
    t.datetime "created_at", null: false
    t.datetime "released_at"
    t.bigint "teller_session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["cash_location_id"], name: "index_cash_location_assignments_on_cash_location_id"
    t.index ["teller_session_id", "cash_location_id", "assigned_at"], name: "idx_cash_location_assignments_lifecycle"
    t.index ["teller_session_id"], name: "index_cash_location_assignments_on_teller_session_id"
  end

  create_table "cash_locations", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.bigint "branch_id", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "location_type", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id", "code"], name: "index_cash_locations_on_branch_id_and_code", unique: true
    t.index ["branch_id"], name: "index_cash_locations_on_branch_id"
    t.index ["location_type"], name: "index_cash_locations_on_location_type"
  end

  create_table "cash_movements", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.bigint "cash_location_id", null: false
    t.datetime "created_at", null: false
    t.string "direction", null: false
    t.bigint "teller_session_id", null: false
    t.bigint "teller_transaction_id", null: false
    t.datetime "updated_at", null: false
    t.index ["cash_location_id"], name: "index_cash_movements_on_cash_location_id"
    t.index ["direction"], name: "index_cash_movements_on_direction"
    t.index ["teller_session_id"], name: "index_cash_movements_on_teller_session_id"
    t.index ["teller_transaction_id"], name: "index_cash_movements_on_teller_transaction_id"
  end

  create_table "permissions", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_permissions_on_key", unique: true
  end

  create_table "posting_batches", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "committed_at", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.text "metadata", size: :long, collation: "utf8mb4_bin"
    t.string "request_id", null: false
    t.string "status", default: "committed", null: false
    t.bigint "teller_transaction_id", null: false
    t.datetime "updated_at", null: false
    t.index ["request_id"], name: "index_posting_batches_on_request_id", unique: true
    t.index ["teller_transaction_id"], name: "index_posting_batches_on_teller_transaction_id"
    t.check_constraint "json_valid(`metadata`)", name: "metadata"
  end

  create_table "posting_legs", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.string "account_reference", null: false
    t.integer "amount_cents", null: false
    t.datetime "created_at", null: false
    t.integer "position", null: false
    t.bigint "posting_batch_id", null: false
    t.string "side", null: false
    t.datetime "updated_at", null: false
    t.index ["posting_batch_id", "position"], name: "index_posting_legs_on_posting_batch_id_and_position", unique: true
    t.index ["posting_batch_id"], name: "index_posting_legs_on_posting_batch_id"
    t.index ["side"], name: "index_posting_legs_on_side"
  end

  create_table "role_permissions", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "permission_id", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["permission_id"], name: "index_role_permissions_on_permission_id"
    t.index ["role_id", "permission_id"], name: "index_role_permissions_on_role_id_and_permission_id", unique: true
    t.index ["role_id"], name: "index_role_permissions_on_role_id"
  end

  create_table "roles", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_roles_on_key", unique: true
  end

  create_table "sessions", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "teller_sessions", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "branch_id", null: false
    t.bigint "cash_location_id"
    t.datetime "closed_at"
    t.integer "closing_cash_cents"
    t.datetime "created_at", null: false
    t.datetime "opened_at", null: false
    t.integer "opening_cash_cents", default: 0, null: false
    t.string "status", default: "open", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workstation_id", null: false
    t.index ["branch_id", "workstation_id", "status"], name: "idx_teller_sessions_branch_workstation_status"
    t.index ["branch_id"], name: "index_teller_sessions_on_branch_id"
    t.index ["cash_location_id"], name: "index_teller_sessions_on_cash_location_id"
    t.index ["user_id", "status"], name: "index_teller_sessions_on_user_id_and_status"
    t.index ["user_id"], name: "index_teller_sessions_on_user_id"
    t.index ["workstation_id"], name: "index_teller_sessions_on_workstation_id"
  end

  create_table "teller_transactions", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.bigint "branch_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "USD", null: false
    t.datetime "posted_at", null: false
    t.string "request_id", null: false
    t.string "status", default: "posted", null: false
    t.bigint "teller_session_id", null: false
    t.string "transaction_type", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workstation_id", null: false
    t.index ["branch_id"], name: "index_teller_transactions_on_branch_id"
    t.index ["request_id"], name: "index_teller_transactions_on_request_id", unique: true
    t.index ["teller_session_id", "posted_at"], name: "index_teller_transactions_on_teller_session_id_and_posted_at"
    t.index ["teller_session_id"], name: "index_teller_transactions_on_teller_session_id"
    t.index ["user_id"], name: "index_teller_transactions_on_user_id"
    t.index ["workstation_id"], name: "index_teller_transactions_on_workstation_id"
  end

  create_table "user_roles", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "branch_id"
    t.datetime "created_at", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.bigint "workstation_id"
    t.index ["branch_id"], name: "index_user_roles_on_branch_id"
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["user_id", "role_id", "branch_id", "workstation_id"], name: "idx_on_user_id_role_id_branch_id_workstation_id_062e1e065a", unique: true
    t.index ["user_id"], name: "index_user_roles_on_user_id"
    t.index ["workstation_id"], name: "index_user_roles_on_workstation_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "workstations", charset: "utf8mb4", collation: "utf8mb4_general_ci", force: :cascade do |t|
    t.bigint "branch_id", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["branch_id", "code"], name: "index_workstations_on_branch_id_and_code", unique: true
    t.index ["branch_id"], name: "index_workstations_on_branch_id"
  end

  add_foreign_key "account_transactions", "posting_batches"
  add_foreign_key "account_transactions", "teller_transactions"
  add_foreign_key "audit_events", "branches"
  add_foreign_key "audit_events", "teller_sessions"
  add_foreign_key "audit_events", "users", column: "actor_user_id"
  add_foreign_key "audit_events", "workstations"
  add_foreign_key "cash_location_assignments", "cash_locations"
  add_foreign_key "cash_location_assignments", "teller_sessions"
  add_foreign_key "cash_locations", "branches"
  add_foreign_key "cash_movements", "cash_locations"
  add_foreign_key "cash_movements", "teller_sessions"
  add_foreign_key "cash_movements", "teller_transactions"
  add_foreign_key "posting_batches", "teller_transactions"
  add_foreign_key "posting_legs", "posting_batches"
  add_foreign_key "role_permissions", "permissions"
  add_foreign_key "role_permissions", "roles"
  add_foreign_key "sessions", "users"
  add_foreign_key "teller_sessions", "branches"
  add_foreign_key "teller_sessions", "cash_locations"
  add_foreign_key "teller_sessions", "users"
  add_foreign_key "teller_sessions", "workstations"
  add_foreign_key "teller_transactions", "branches"
  add_foreign_key "teller_transactions", "teller_sessions"
  add_foreign_key "teller_transactions", "users"
  add_foreign_key "teller_transactions", "workstations"
  add_foreign_key "user_roles", "branches"
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "users"
  add_foreign_key "user_roles", "workstations"
  add_foreign_key "workstations", "branches"
end
