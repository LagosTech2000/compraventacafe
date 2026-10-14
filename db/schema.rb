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

ActiveRecord::Schema[8.1].define(version: 2026_10_13_130200) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_events", force: :cascade do |t|
    t.bigint "user_id"
    t.string "user_email"
    t.string "action", null: false
    t.string "auditable_type"
    t.bigint "auditable_id"
    t.string "auditable_label"
    t.jsonb "changeset", default: {}, null: false
    t.string "ip_address"
    t.string "request_id"
    t.datetime "created_at", null: false
    t.jsonb "details", default: {}, null: false
    t.index ["action"], name: "index_audit_events_on_action"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_events_on_auditable_type_and_auditable_id"
    t.index ["created_at"], name: "index_audit_events_on_created_at"
    t.index ["user_id"], name: "index_audit_events_on_user_id"
  end

  create_table "clients", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_clients_on_person_id", unique: true
  end

  create_table "collaborators", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_collaborators_on_person_id", unique: true
  end

  create_table "departments", force: :cascade do |t|
    t.string "code", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_departments_on_code", unique: true
  end

  create_table "expense_categories", force: :cascade do |t|
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_expense_categories_on_lower_name", unique: true
  end

  create_table "farms", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "department_id"
    t.bigint "municipality_id"
    t.text "address_line"
    t.text "observations"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "producer_id"
    t.decimal "latitude", precision: 9, scale: 6
    t.decimal "longitude", precision: 9, scale: 6
    t.index "lower((name)::text)", name: "index_farms_on_lower_name", unique: true, where: "(producer_id IS NULL)"
    t.index "producer_id, lower((name)::text)", name: "index_farms_on_producer_and_lower_name", unique: true, where: "(producer_id IS NOT NULL)"
    t.index ["department_id"], name: "index_farms_on_department_id"
    t.index ["municipality_id"], name: "index_farms_on_municipality_id"
    t.index ["producer_id"], name: "index_farms_on_producer_id"
  end

  create_table "harvest_entries", force: :cascade do |t|
    t.bigint "payroll_member_id", null: false
    t.date "worked_on", null: false
    t.decimal "cans", precision: 8, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payroll_member_id", "worked_on"], name: "index_harvest_entries_on_payroll_member_id_and_worked_on", unique: true
    t.index ["payroll_member_id"], name: "index_harvest_entries_on_payroll_member_id"
    t.index ["worked_on"], name: "index_harvest_entries_on_worked_on"
  end

  create_table "invoice_payments", force: :cascade do |t|
    t.bigint "invoice_id", null: false
    t.bigint "created_by_id", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.date "paid_on", null: false
    t.string "payment_method", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_invoice_payments_on_created_by_id"
    t.index ["invoice_id", "paid_on"], name: "index_invoice_payments_on_invoice_id_and_paid_on"
    t.index ["invoice_id"], name: "index_invoice_payments_on_invoice_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.integer "number", null: false
    t.bigint "producer_id", null: false
    t.bigint "created_by_id", null: false
    t.date "issued_on", null: false
    t.string "payment_status", null: false
    t.string "payment_method"
    t.date "paid_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.index ["created_by_id"], name: "index_invoices_on_created_by_id"
    t.index ["issued_on"], name: "index_invoices_on_issued_on"
    t.index ["number"], name: "index_invoices_on_number", unique: true
    t.index ["payment_status"], name: "index_invoices_on_payment_status"
    t.index ["producer_id"], name: "index_invoices_on_producer_id"
  end

  create_table "loan_payments", force: :cascade do |t|
    t.bigint "loan_id", null: false
    t.bigint "created_by_id", null: false
    t.date "paid_on", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.decimal "interest_amount", precision: 14, scale: 2, null: false
    t.decimal "principal_amount", precision: 14, scale: 2, null: false
    t.string "payment_method", null: false
    t.text "observations"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "purchase_id"
    t.bigint "payroll_payment_line_id"
    t.index ["created_by_id"], name: "index_loan_payments_on_created_by_id"
    t.index ["loan_id"], name: "index_loan_payments_on_loan_id"
    t.index ["paid_on"], name: "index_loan_payments_on_paid_on"
    t.index ["payroll_payment_line_id"], name: "index_loan_payments_on_payroll_payment_line_id"
    t.index ["purchase_id"], name: "index_loan_payments_on_purchase_id"
  end

  create_table "loan_supplies", force: :cascade do |t|
    t.bigint "loan_id", null: false
    t.bigint "supply_id", null: false
    t.decimal "quantity", precision: 10, scale: 2, null: false
    t.decimal "unit_price", precision: 12, scale: 2, null: false
    t.decimal "total", precision: 14, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["loan_id"], name: "index_loan_supplies_on_loan_id"
    t.index ["supply_id"], name: "index_loan_supplies_on_supply_id"
  end

  create_table "loans", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.bigint "created_by_id", null: false
    t.decimal "principal", precision: 14, scale: 2, null: false
    t.decimal "monthly_interest_rate", precision: 5, scale: 2, null: false
    t.date "disbursed_on", null: false
    t.date "due_on", null: false
    t.date "paid_off_on"
    t.text "observations"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "cash_amount", precision: 14, scale: 2, default: "0.0", null: false
    t.integer "lock_version", default: 0, null: false
    t.index ["created_by_id"], name: "index_loans_on_created_by_id"
    t.index ["disbursed_on"], name: "index_loans_on_disbursed_on"
    t.index ["due_on"], name: "index_loans_on_due_on"
    t.index ["person_id"], name: "index_loans_on_person_id"
  end

  create_table "municipalities", force: :cascade do |t|
    t.bigint "department_id", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_municipalities_on_code", unique: true
    t.index ["department_id"], name: "index_municipalities_on_department_id"
  end

  create_table "payroll_attendances", force: :cascade do |t|
    t.bigint "payroll_member_id", null: false
    t.date "worked_on", null: false
    t.decimal "day_fraction", precision: 3, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payroll_member_id", "worked_on"], name: "index_payroll_attendances_on_payroll_member_id_and_worked_on", unique: true
    t.index ["payroll_member_id"], name: "index_payroll_attendances_on_payroll_member_id"
    t.index ["worked_on"], name: "index_payroll_attendances_on_worked_on"
  end

  create_table "payroll_expenses", force: :cascade do |t|
    t.bigint "payroll_id", null: false
    t.bigint "expense_category_id", null: false
    t.bigint "created_by_id", null: false
    t.date "spent_on", null: false
    t.string "description", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_payroll_expenses_on_created_by_id"
    t.index ["expense_category_id"], name: "index_payroll_expenses_on_expense_category_id"
    t.index ["payroll_id"], name: "index_payroll_expenses_on_payroll_id"
    t.index ["spent_on"], name: "index_payroll_expenses_on_spent_on"
  end

  create_table "payroll_members", force: :cascade do |t|
    t.bigint "payroll_id", null: false
    t.bigint "person_id", null: false
    t.bigint "payroll_role_id"
    t.decimal "daily_wage_override", precision: 10, scale: 2
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payroll_id", "person_id"], name: "index_payroll_members_on_payroll_id_and_person_id", unique: true
    t.index ["payroll_id"], name: "index_payroll_members_on_payroll_id"
    t.index ["payroll_role_id"], name: "index_payroll_members_on_payroll_role_id"
    t.index ["person_id"], name: "index_payroll_members_on_person_id"
  end

  create_table "payroll_payment_lines", force: :cascade do |t|
    t.bigint "payroll_payment_id", null: false
    t.bigint "payroll_member_id", null: false
    t.decimal "quantity", precision: 10, scale: 2, null: false
    t.decimal "rate", precision: 10, scale: 2
    t.decimal "gross_amount", precision: 14, scale: 2, null: false
    t.decimal "loans_amount", precision: 14, scale: 2, default: "0.0", null: false
    t.decimal "net_amount", precision: 14, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "basis", null: false
    t.index ["payroll_member_id"], name: "index_payroll_payment_lines_on_payroll_member_id"
    t.index ["payroll_payment_id"], name: "index_payroll_payment_lines_on_payroll_payment_id"
  end

  create_table "payroll_payments", force: :cascade do |t|
    t.bigint "payroll_id", null: false
    t.bigint "created_by_id", null: false
    t.date "period_starts_on", null: false
    t.date "period_ends_on", null: false
    t.date "paid_on", null: false
    t.decimal "gross_total", precision: 14, scale: 2, null: false
    t.decimal "loans_total", precision: 14, scale: 2, null: false
    t.decimal "net_total", precision: 14, scale: 2, null: false
    t.text "observations"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_payroll_payments_on_created_by_id"
    t.index ["paid_on"], name: "index_payroll_payments_on_paid_on"
    t.index ["payroll_id", "period_starts_on"], name: "index_payroll_payments_on_payroll_id_and_period_starts_on", unique: true
    t.index ["payroll_id"], name: "index_payroll_payments_on_payroll_id"
  end

  create_table "payroll_roles", force: :cascade do |t|
    t.bigint "payroll_id", null: false
    t.string "name", null: false
    t.decimal "daily_wage", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "payroll_id, lower((name)::text)", name: "index_payroll_roles_on_payroll_and_lower_name", unique: true
    t.index ["payroll_id"], name: "index_payroll_roles_on_payroll_id"
  end

  create_table "payroll_task_participants", force: :cascade do |t|
    t.bigint "payroll_task_id", null: false
    t.bigint "payroll_member_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payroll_member_id"], name: "index_payroll_task_participants_on_payroll_member_id"
    t.index ["payroll_task_id", "payroll_member_id"], name: "index_task_participants_on_task_and_member", unique: true
    t.index ["payroll_task_id"], name: "index_payroll_task_participants_on_payroll_task_id"
  end

  create_table "payroll_tasks", force: :cascade do |t|
    t.bigint "payroll_id", null: false
    t.string "name", null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.date "completed_on"
    t.text "observations"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payroll_id"], name: "index_payroll_tasks_on_payroll_id"
  end

  create_table "payrolls", force: :cascade do |t|
    t.bigint "farm_id", null: false
    t.bigint "created_by_id", null: false
    t.string "name", null: false
    t.string "kind", null: false
    t.string "pay_frequency", null: false
    t.date "starts_on", null: false
    t.date "ends_on"
    t.decimal "can_price", precision: 10, scale: 2
    t.text "observations"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.index ["created_by_id"], name: "index_payrolls_on_created_by_id"
    t.index ["farm_id"], name: "index_payrolls_on_farm_id"
  end

  create_table "people", force: :cascade do |t|
    t.string "first_names", null: false
    t.string "last_names", null: false
    t.string "dni"
    t.string "rtn"
    t.string "phone"
    t.string "email"
    t.text "address_line"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "department_id"
    t.bigint "municipality_id"
    t.bigint "zone_id"
    t.decimal "latitude", precision: 9, scale: 6
    t.decimal "longitude", precision: 9, scale: 6
    t.index ["department_id"], name: "index_people_on_department_id"
    t.index ["dni"], name: "index_people_on_dni", unique: true, where: "(dni IS NOT NULL)"
    t.index ["last_names", "first_names"], name: "index_people_on_last_names_and_first_names"
    t.index ["municipality_id"], name: "index_people_on_municipality_id"
    t.index ["rtn"], name: "index_people_on_rtn", unique: true, where: "(rtn IS NOT NULL)"
    t.index ["zone_id"], name: "index_people_on_zone_id"
  end

  create_table "permissions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "module_key", null: false
    t.boolean "can_read", default: false, null: false
    t.boolean "can_create", default: false, null: false
    t.boolean "can_update", default: false, null: false
    t.boolean "can_destroy", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "module_key"], name: "index_permissions_on_user_id_and_module_key", unique: true
  end

  create_table "producers", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.string "kind", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "ihcafe_code"
    t.index ["ihcafe_code"], name: "index_producers_on_ihcafe_code", unique: true, where: "(ihcafe_code IS NOT NULL)"
    t.index ["person_id"], name: "index_producers_on_person_id", unique: true
  end

  create_table "profile_photos", force: :cascade do |t|
    t.string "owner_type", null: false
    t.bigint "owner_id", null: false
    t.binary "data", null: false
    t.string "content_type", null: false
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id"], name: "index_profile_photos_on_owner", unique: true
  end

  create_table "purchase_weighings", force: :cascade do |t|
    t.bigint "purchase_id", null: false
    t.decimal "gross_weight", precision: 10, scale: 2, null: false
    t.integer "sacks", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["purchase_id"], name: "index_purchase_weighings_on_purchase_id"
  end

  create_table "purchases", force: :cascade do |t|
    t.bigint "producer_id", null: false
    t.bigint "zone_id"
    t.bigint "invoice_id"
    t.bigint "created_by_id", null: false
    t.string "coffee_state", null: false
    t.decimal "gross_weight", precision: 10, scale: 2, null: false
    t.decimal "humidity_percent", precision: 5, scale: 2
    t.decimal "price_per_pound", precision: 10, scale: 2, null: false
    t.decimal "sacks", precision: 10, scale: 4, null: false
    t.decimal "tare", precision: 10, scale: 2, null: false
    t.decimal "net_weight", precision: 12, scale: 2, null: false
    t.decimal "total", precision: 14, scale: 2, null: false
    t.text "observations"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "damage_percent", precision: 5, scale: 2
    t.decimal "yield_factor", precision: 6, scale: 4
    t.integer "season_year", null: false
    t.datetime "voided_at"
    t.bigint "voided_by_id"
    t.datetime "purchased_at", null: false
    t.string "weight_mode", default: "single", null: false
    t.decimal "damage_weight", precision: 12, scale: 2
    t.decimal "damage_amount", precision: 14, scale: 2
    t.bigint "farm_id"
    t.integer "lock_version", default: 0, null: false
    t.index ["created_by_id"], name: "index_purchases_on_created_by_id"
    t.index ["farm_id"], name: "index_purchases_on_farm_id"
    t.index ["invoice_id"], name: "index_purchases_on_invoice_id"
    t.index ["producer_id"], name: "index_purchases_on_producer_id"
    t.index ["purchased_at"], name: "index_purchases_on_purchased_at"
    t.index ["season_year"], name: "index_purchases_on_season_year"
    t.index ["voided_at"], name: "index_purchases_on_voided_at"
    t.index ["voided_by_id"], name: "index_purchases_on_voided_by_id"
    t.index ["zone_id"], name: "index_purchases_on_zone_id"
  end

  create_table "saved_reports", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "report_key", null: false
    t.string "name", null: false
    t.jsonb "params", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "user_id, lower((name)::text)", name: "index_saved_reports_on_user_and_lower_name", unique: true
    t.index ["user_id"], name: "index_saved_reports_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "site_settings", force: :cascade do |t|
    t.string "business_name", null: false
    t.string "location"
    t.binary "logo_data"
    t.string "logo_content_type"
    t.string "logo_filename"
    t.integer "logo_byte_size"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "supplies", force: :cascade do |t|
    t.string "name", null: false
    t.string "unit", null: false
    t.decimal "default_price", precision: 12, scale: 2, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_supplies_on_lower_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.boolean "admin", default: false, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name", null: false
    t.string "window_style", default: "modal", null: false
    t.string "nav_position", default: "top", null: false
    t.string "webauthn_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["webauthn_id"], name: "index_users_on_webauthn_id", unique: true
  end

  create_table "webauthn_credentials", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "external_id", null: false
    t.text "public_key", null: false
    t.bigint "sign_count", default: 0, null: false
    t.string "nickname", null: false
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_webauthn_credentials_on_external_id", unique: true
    t.index ["user_id"], name: "index_webauthn_credentials_on_user_id"
  end

  create_table "zones", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_zones_on_lower_name", unique: true
  end

  add_foreign_key "audit_events", "users", on_delete: :nullify
  add_foreign_key "clients", "people"
  add_foreign_key "collaborators", "people"
  add_foreign_key "farms", "departments"
  add_foreign_key "farms", "municipalities"
  add_foreign_key "farms", "producers"
  add_foreign_key "harvest_entries", "payroll_members"
  add_foreign_key "invoice_payments", "invoices"
  add_foreign_key "invoice_payments", "users", column: "created_by_id"
  add_foreign_key "invoices", "producers"
  add_foreign_key "invoices", "users", column: "created_by_id"
  add_foreign_key "loan_payments", "loans"
  add_foreign_key "loan_payments", "payroll_payment_lines"
  add_foreign_key "loan_payments", "purchases"
  add_foreign_key "loan_payments", "users", column: "created_by_id"
  add_foreign_key "loan_supplies", "loans"
  add_foreign_key "loan_supplies", "supplies"
  add_foreign_key "loans", "people"
  add_foreign_key "loans", "users", column: "created_by_id"
  add_foreign_key "municipalities", "departments"
  add_foreign_key "payroll_attendances", "payroll_members"
  add_foreign_key "payroll_expenses", "expense_categories"
  add_foreign_key "payroll_expenses", "payrolls"
  add_foreign_key "payroll_expenses", "users", column: "created_by_id"
  add_foreign_key "payroll_members", "payroll_roles"
  add_foreign_key "payroll_members", "payrolls"
  add_foreign_key "payroll_members", "people"
  add_foreign_key "payroll_payment_lines", "payroll_members"
  add_foreign_key "payroll_payment_lines", "payroll_payments"
  add_foreign_key "payroll_payments", "payrolls"
  add_foreign_key "payroll_payments", "users", column: "created_by_id"
  add_foreign_key "payroll_roles", "payrolls"
  add_foreign_key "payroll_task_participants", "payroll_members"
  add_foreign_key "payroll_task_participants", "payroll_tasks"
  add_foreign_key "payroll_tasks", "payrolls"
  add_foreign_key "payrolls", "farms"
  add_foreign_key "payrolls", "users", column: "created_by_id"
  add_foreign_key "people", "departments"
  add_foreign_key "people", "municipalities"
  add_foreign_key "people", "zones"
  add_foreign_key "permissions", "users"
  add_foreign_key "producers", "people"
  add_foreign_key "purchase_weighings", "purchases"
  add_foreign_key "purchases", "farms"
  add_foreign_key "purchases", "invoices"
  add_foreign_key "purchases", "producers"
  add_foreign_key "purchases", "users", column: "created_by_id"
  add_foreign_key "purchases", "users", column: "voided_by_id"
  add_foreign_key "purchases", "zones"
  add_foreign_key "saved_reports", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "webauthn_credentials", "users"
end
