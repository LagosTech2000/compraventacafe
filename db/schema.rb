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

ActiveRecord::Schema[8.1].define(version: 2026_10_26_040000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_stat_statements"

  create_table "account_transfers", force: :cascade do |t|
    t.date "transferred_on", null: false
    t.bigint "from_account_id", null: false
    t.bigint "to_account_id", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.text "observations"
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_account_transfers_on_created_by_id"
    t.index ["from_account_id"], name: "index_account_transfers_on_from_account_id"
    t.index ["to_account_id"], name: "index_account_transfers_on_to_account_id"
    t.index ["transferred_on"], name: "index_account_transfers_on_transferred_on"
  end

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

  create_table "budgets", force: :cascade do |t|
    t.bigint "finance_category_id", null: false
    t.date "month", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["finance_category_id", "month"], name: "index_budgets_on_finance_category_id_and_month", unique: true
  end

  create_table "buyer_advances", force: :cascade do |t|
    t.bigint "buyer_id", null: false
    t.date "received_on", null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.string "payment_method", null: false
    t.bigint "money_account_id", null: false
    t.string "document_number"
    t.text "observations"
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["buyer_id"], name: "index_buyer_advances_on_buyer_id"
    t.index ["created_by_id"], name: "index_buyer_advances_on_created_by_id"
    t.index ["money_account_id"], name: "index_buyer_advances_on_money_account_id"
  end

  create_table "buyers", force: :cascade do |t|
    t.string "name", null: false
    t.string "kind", null: false
    t.string "rtn"
    t.string "phone"
    t.string "email"
    t.string "contact_name"
    t.bigint "department_id"
    t.bigint "municipality_id"
    t.text "address_line"
    t.decimal "latitude", precision: 9, scale: 6
    t.decimal "longitude", precision: 9, scale: 6
    t.text "observations"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_buyers_on_lower_name", unique: true
    t.index ["department_id"], name: "index_buyers_on_department_id"
    t.index ["municipality_id"], name: "index_buyers_on_municipality_id"
    t.index ["rtn"], name: "index_buyers_on_rtn", unique: true, where: "(rtn IS NOT NULL)"
  end

  create_table "carriers", force: :cascade do |t|
    t.string "name", null: false
    t.string "rtn"
    t.string "phone"
    t.string "contact_name"
    t.text "observations"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_carriers_on_lower_name", unique: true
  end

  create_table "cash_counts", force: :cascade do |t|
    t.bigint "money_account_id", null: false
    t.date "counted_on", null: false
    t.decimal "counted_amount", precision: 14, scale: 2, null: false
    t.decimal "system_balance", precision: 14, scale: 2, null: false
    t.string "observations"
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_cash_counts_on_created_by_id"
    t.index ["money_account_id", "counted_on"], name: "index_cash_counts_on_money_account_id_and_counted_on"
    t.index ["money_account_id"], name: "index_cash_counts_on_money_account_id"
  end

  create_table "clients", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_clients_on_person_id", unique: true
  end

  create_table "coffee_conversions", force: :cascade do |t|
    t.integer "number", null: false
    t.string "from_state", null: false
    t.string "to_state", null: false
    t.datetime "weighed_at", null: false
    t.decimal "input_gross_weight", precision: 12, scale: 2, null: false
    t.decimal "input_net_weight", precision: 12, scale: 2, null: false
    t.decimal "input_ratio", precision: 8, scale: 6, null: false
    t.string "input_ratio_source", null: false
    t.datetime "finished_at"
    t.decimal "output_gross_weight", precision: 12, scale: 2
    t.decimal "output_net_weight", precision: 12, scale: 2
    t.decimal "output_ratio", precision: 8, scale: 6
    t.string "output_ratio_source"
    t.text "observations"
    t.bigint "created_by_id", null: false
    t.bigint "finished_by_id"
    t.datetime "voided_at"
    t.bigint "voided_by_id"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "output_sacks"
    t.decimal "output_tare", precision: 12, scale: 2
    t.decimal "output_humidity_percent", precision: 5, scale: 2
    t.decimal "output_damage_percent", precision: 5, scale: 2
    t.index ["created_by_id"], name: "index_coffee_conversions_on_created_by_id"
    t.index ["finished_at"], name: "index_coffee_conversions_on_finished_at"
    t.index ["finished_by_id"], name: "index_coffee_conversions_on_finished_by_id"
    t.index ["number"], name: "index_coffee_conversions_on_number", unique: true
    t.index ["voided_by_id"], name: "index_coffee_conversions_on_voided_by_id"
    t.index ["weighed_at"], name: "index_coffee_conversions_on_weighed_at"
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

  create_table "expense_receipts", force: :cascade do |t|
    t.bigint "expense_id", null: false
    t.binary "data", null: false
    t.string "content_type", null: false
    t.string "filename"
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expense_id"], name: "index_expense_receipts_on_expense_id", unique: true
  end

  create_table "expenses", force: :cascade do |t|
    t.string "kind", null: false
    t.date "spent_on", null: false
    t.bigint "finance_category_id", null: false
    t.bigint "money_account_id", null: false
    t.string "payee"
    t.string "description", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.string "payment_method", null: false
    t.string "receipt_number"
    t.text "observations"
    t.bigint "created_by_id", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_expenses_on_created_by_id"
    t.index ["finance_category_id"], name: "index_expenses_on_finance_category_id"
    t.index ["kind"], name: "index_expenses_on_kind"
    t.index ["money_account_id"], name: "index_expenses_on_money_account_id"
    t.index ["spent_on"], name: "index_expenses_on_spent_on"
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
    t.decimal "area_value", precision: 14, scale: 4
    t.string "area_unit"
    t.index "lower((name)::text)", name: "index_farms_on_lower_name", unique: true, where: "(producer_id IS NULL)"
    t.index "producer_id, lower((name)::text)", name: "index_farms_on_producer_and_lower_name", unique: true, where: "(producer_id IS NOT NULL)"
    t.index ["department_id"], name: "index_farms_on_department_id"
    t.index ["municipality_id"], name: "index_farms_on_municipality_id"
    t.index ["producer_id"], name: "index_farms_on_producer_id"
  end

  create_table "finance_categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "kind", null: false
    t.bigint "parent_id"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "kind, COALESCE(parent_id, (0)::bigint), lower((name)::text)", name: "index_finance_categories_on_name_in_parent", unique: true
    t.index ["parent_id"], name: "index_finance_categories_on_parent_id"
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

  create_table "hauler_payments", force: :cascade do |t|
    t.bigint "hauler_id", null: false
    t.bigint "created_by_id", null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.decimal "balance_after", precision: 12, scale: 2, null: false
    t.date "paid_on", null: false
    t.string "payment_method", null: false
    t.text "observations"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "money_account_id"
    t.index ["created_by_id"], name: "index_hauler_payments_on_created_by_id"
    t.index ["hauler_id"], name: "index_hauler_payments_on_hauler_id"
    t.index ["money_account_id"], name: "index_hauler_payments_on_money_account_id"
  end

  create_table "haulers", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "price_per_pound", precision: 12, scale: 4, null: false
    t.index ["person_id"], name: "index_haulers_on_person_id", unique: true
  end

  create_table "invoice_payments", force: :cascade do |t|
    t.bigint "invoice_id", null: false
    t.bigint "created_by_id", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.date "paid_on", null: false
    t.string "payment_method", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "money_account_id"
    t.index ["created_by_id"], name: "index_invoice_payments_on_created_by_id"
    t.index ["invoice_id", "paid_on"], name: "index_invoice_payments_on_invoice_id_and_paid_on"
    t.index ["invoice_id"], name: "index_invoice_payments_on_invoice_id"
    t.index ["money_account_id"], name: "index_invoice_payments_on_money_account_id"
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
    t.bigint "money_account_id"
    t.index ["created_by_id"], name: "index_loan_payments_on_created_by_id"
    t.index ["loan_id"], name: "index_loan_payments_on_loan_id"
    t.index ["money_account_id"], name: "index_loan_payments_on_money_account_id"
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
    t.bigint "money_account_id"
    t.boolean "interest_grace", default: false, null: false
    t.index ["created_by_id"], name: "index_loans_on_created_by_id"
    t.index ["disbursed_on"], name: "index_loans_on_disbursed_on"
    t.index ["due_on"], name: "index_loans_on_due_on"
    t.index ["money_account_id"], name: "index_loans_on_money_account_id"
    t.index ["person_id"], name: "index_loans_on_person_id"
  end

  create_table "money_accounts", force: :cascade do |t|
    t.string "name", null: false
    t.string "kind", null: false
    t.string "bank_name"
    t.string "account_number"
    t.decimal "opening_balance", precision: 14, scale: 2, default: "0.0", null: false
    t.date "opening_on", null: false
    t.string "default_for", default: [], null: false, array: true
    t.text "observations"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "bank_key"
    t.index "lower((name)::text)", name: "index_money_accounts_on_lower_name", unique: true
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

  create_table "other_incomes", force: :cascade do |t|
    t.date "received_on", null: false
    t.bigint "money_account_id", null: false
    t.string "concept", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.string "payment_method", null: false
    t.text "observations"
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_other_incomes_on_created_by_id"
    t.index ["money_account_id"], name: "index_other_incomes_on_money_account_id"
    t.index ["received_on"], name: "index_other_incomes_on_received_on"
  end

  create_table "page_visits", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "path", null: false
    t.string "title"
    t.datetime "visited_at", null: false
    t.index ["user_id", "visited_at"], name: "index_page_visits_on_user_id_and_visited_at"
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
    t.bigint "money_account_id"
    t.index ["created_by_id"], name: "index_payroll_expenses_on_created_by_id"
    t.index ["expense_category_id"], name: "index_payroll_expenses_on_expense_category_id"
    t.index ["money_account_id"], name: "index_payroll_expenses_on_money_account_id"
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
    t.index ["payroll_id", "person_id", "payroll_role_id"], name: "index_payroll_members_on_payroll_person_role", unique: true, nulls_not_distinct: true
    t.index ["payroll_id"], name: "index_payroll_members_on_payroll_id"
    t.index ["payroll_role_id"], name: "index_payroll_members_on_payroll_role_id"
    t.index ["person_id"], name: "index_payroll_members_on_person_id"
  end

  create_table "payroll_overtimes", force: :cascade do |t|
    t.bigint "payroll_member_id", null: false
    t.date "period_starts_on", null: false
    t.decimal "hours", precision: 6, scale: 2, default: "0.0", null: false
    t.decimal "extra_days", precision: 5, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["payroll_member_id", "period_starts_on"], name: "idx_on_payroll_member_id_period_starts_on_ad56fa09ec", unique: true
    t.index ["payroll_member_id"], name: "index_payroll_overtimes_on_payroll_member_id"
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
    t.decimal "overtime_hours", precision: 6, scale: 2, default: "0.0", null: false
    t.decimal "overtime_hour_rate", precision: 10, scale: 2
    t.decimal "extra_days", precision: 5, scale: 2, default: "0.0", null: false
    t.decimal "overtime_amount", precision: 14, scale: 2, default: "0.0", null: false
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
    t.bigint "money_account_id"
    t.index ["created_by_id"], name: "index_payroll_payments_on_created_by_id"
    t.index ["money_account_id"], name: "index_payroll_payments_on_money_account_id"
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
    t.string "pricing", default: "fixed", null: false
    t.decimal "quantity", precision: 12, scale: 2
    t.string "quantity_unit"
    t.decimal "unit_price", precision: 12, scale: 2
    t.decimal "barrel_liters", precision: 8, scale: 2
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
    t.decimal "overtime_hour_rate", precision: 10, scale: 2
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
    t.string "civil_status"
    t.string "nationality"
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

  create_table "private_document_prints", force: :cascade do |t|
    t.bigint "private_document_id", null: false
    t.bigint "person_id", null: false
    t.bigint "loan_id"
    t.bigint "user_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["loan_id"], name: "index_private_document_prints_on_loan_id"
    t.index ["person_id", "private_document_id", "created_at"], name: "index_private_document_prints_on_person_document_and_time"
    t.index ["private_document_id"], name: "index_private_document_prints_on_private_document_id"
    t.index ["user_id"], name: "index_private_document_prints_on_user_id"
  end

  create_table "private_documents", force: :cascade do |t|
    t.string "key", null: false
    t.text "body", default: "", null: false
    t.bigint "updated_by_id"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_private_documents_on_key", unique: true
    t.index ["updated_by_id"], name: "index_private_documents_on_updated_by_id"
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
    t.bigint "hauler_id"
    t.decimal "hauler_commission_percent", precision: 5, scale: 2
    t.decimal "hauler_can_price", precision: 12, scale: 2
    t.decimal "hauler_cans", precision: 12, scale: 2
    t.decimal "hauler_commission", precision: 12, scale: 2
    t.string "damage_types", default: [], null: false, array: true
    t.decimal "hauler_price_per_pound", precision: 12, scale: 4
    t.index ["created_by_id"], name: "index_purchases_on_created_by_id"
    t.index ["farm_id"], name: "index_purchases_on_farm_id"
    t.index ["hauler_id"], name: "index_purchases_on_hauler_id"
    t.index ["invoice_id"], name: "index_purchases_on_invoice_id"
    t.index ["producer_id"], name: "index_purchases_on_producer_id"
    t.index ["purchased_at"], name: "index_purchases_on_purchased_at"
    t.index ["season_year"], name: "index_purchases_on_season_year"
    t.index ["voided_at"], name: "index_purchases_on_voided_at"
    t.index ["voided_by_id"], name: "index_purchases_on_voided_by_id"
    t.index ["zone_id"], name: "index_purchases_on_zone_id"
  end

  create_table "sale_lines", force: :cascade do |t|
    t.bigint "sale_id", null: false
    t.bigint "shipment_id", null: false
    t.decimal "origin_net_weight", precision: 12, scale: 2, null: false
    t.decimal "net_weight", precision: 12, scale: 2, null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sale_id"], name: "index_sale_lines_on_sale_id"
    t.index ["shipment_id"], name: "index_sale_lines_on_active_shipment", unique: true, where: "active"
    t.index ["shipment_id"], name: "index_sale_lines_on_shipment_id"
  end

  create_table "sale_payments", force: :cascade do |t|
    t.bigint "sale_id", null: false
    t.bigint "created_by_id", null: false
    t.decimal "amount", precision: 14, scale: 2, null: false
    t.date "paid_on", null: false
    t.string "payment_method", null: false
    t.text "observations"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "money_account_id"
    t.index ["created_by_id"], name: "index_sale_payments_on_created_by_id"
    t.index ["money_account_id"], name: "index_sale_payments_on_money_account_id"
    t.index ["paid_on"], name: "index_sale_payments_on_paid_on"
    t.index ["sale_id"], name: "index_sale_payments_on_sale_id"
  end

  create_table "sales", force: :cascade do |t|
    t.integer "number", null: false
    t.bigint "buyer_id", null: false
    t.bigint "created_by_id", null: false
    t.date "sold_on", null: false
    t.string "coffee_state", null: false
    t.string "price_unit", null: false
    t.decimal "unit_price", precision: 12, scale: 2, null: false
    t.string "buyer_document_number"
    t.text "observations"
    t.decimal "origin_net_weight", precision: 14, scale: 2, null: false
    t.decimal "net_weight", precision: 14, scale: 2, null: false
    t.decimal "total", precision: 14, scale: 2, null: false
    t.string "payment_status", null: false
    t.string "payment_method"
    t.date "paid_on"
    t.datetime "voided_at"
    t.bigint "voided_by_id"
    t.string "void_reason"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "quintal_pounds", precision: 8, scale: 2, default: "120.0", null: false
    t.decimal "buyer_total", precision: 14, scale: 2
    t.string "buyer_total_reason"
    t.index ["buyer_id"], name: "index_sales_on_buyer_id"
    t.index ["created_by_id"], name: "index_sales_on_created_by_id"
    t.index ["number"], name: "index_sales_on_number", unique: true
    t.index ["payment_status"], name: "index_sales_on_payment_status"
    t.index ["sold_on"], name: "index_sales_on_sold_on"
    t.index ["voided_by_id"], name: "index_sales_on_voided_by_id"
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
    t.datetime "last_seen_at"
    t.string "last_path"
    t.string "last_page_title"
    t.index ["last_seen_at"], name: "index_sessions_on_last_seen_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "shipment_weighings", force: :cascade do |t|
    t.bigint "shipment_id", null: false
    t.decimal "gross_weight", precision: 12, scale: 2, null: false
    t.integer "sacks", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shipment_id"], name: "index_shipment_weighings_on_shipment_id"
  end

  create_table "shipments", force: :cascade do |t|
    t.integer "number", null: false
    t.bigint "buyer_id", null: false
    t.bigint "created_by_id", null: false
    t.datetime "departed_at", null: false
    t.integer "season_year", null: false
    t.string "coffee_state", null: false
    t.string "remission_number"
    t.text "observations"
    t.decimal "origin_gross_weight", precision: 12, scale: 2, null: false
    t.integer "origin_sacks", null: false
    t.decimal "origin_humidity_percent", precision: 5, scale: 2
    t.decimal "origin_damage_percent", precision: 5, scale: 2
    t.decimal "origin_yield_factor", precision: 6, scale: 4
    t.decimal "origin_tare", precision: 12, scale: 2, null: false
    t.decimal "origin_net_weight", precision: 12, scale: 2, null: false
    t.date "received_on"
    t.string "weight_note_number"
    t.decimal "destination_gross_weight", precision: 12, scale: 2
    t.integer "destination_sacks"
    t.decimal "destination_humidity_percent", precision: 5, scale: 2
    t.decimal "destination_damage_percent", precision: 5, scale: 2
    t.decimal "destination_yield_factor", precision: 6, scale: 4
    t.decimal "destination_tare", precision: 12, scale: 2
    t.decimal "destination_net_weight", precision: 12, scale: 2
    t.datetime "voided_at"
    t.bigint "voided_by_id"
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "origin_weight_mode", default: "single", null: false
    t.bigint "carrier_id"
    t.bigint "truck_id"
    t.bigint "driver_id"
    t.string "driver_name"
    t.index ["buyer_id"], name: "index_shipments_on_buyer_id"
    t.index ["carrier_id"], name: "index_shipments_on_carrier_id"
    t.index ["created_by_id"], name: "index_shipments_on_created_by_id"
    t.index ["departed_at"], name: "index_shipments_on_departed_at"
    t.index ["driver_id"], name: "index_shipments_on_driver_id"
    t.index ["number"], name: "index_shipments_on_number", unique: true
    t.index ["season_year"], name: "index_shipments_on_season_year"
    t.index ["truck_id"], name: "index_shipments_on_truck_id"
    t.index ["voided_by_id"], name: "index_shipments_on_voided_by_id"
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
    t.string "rtn"
    t.decimal "weight_tolerance_percent", precision: 5, scale: 2
  end

  create_table "staff_advances", force: :cascade do |t|
    t.bigint "staff_member_id", null: false
    t.date "given_on", null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.string "payment_method", null: false
    t.bigint "money_account_id", null: false
    t.text "observations"
    t.bigint "staff_payment_id"
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_staff_advances_on_created_by_id"
    t.index ["money_account_id"], name: "index_staff_advances_on_money_account_id"
    t.index ["staff_member_id"], name: "index_staff_advances_on_staff_member_id"
    t.index ["staff_payment_id"], name: "index_staff_advances_on_staff_payment_id"
  end

  create_table "staff_attendances", force: :cascade do |t|
    t.bigint "staff_member_id", null: false
    t.date "worked_on", null: false
    t.decimal "day_fraction", precision: 3, scale: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["staff_member_id", "worked_on"], name: "index_staff_attendances_on_staff_member_id_and_worked_on", unique: true
  end

  create_table "staff_goals", force: :cascade do |t|
    t.bigint "staff_member_id", null: false
    t.date "period_starts_on", null: false
    t.string "description", null: false
    t.decimal "bonus_amount", precision: 12, scale: 2, null: false
    t.boolean "met"
    t.bigint "staff_payment_id"
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_staff_goals_on_created_by_id"
    t.index ["staff_member_id"], name: "index_staff_goals_on_staff_member_id"
    t.index ["staff_payment_id"], name: "index_staff_goals_on_staff_payment_id"
  end

  create_table "staff_members", force: :cascade do |t|
    t.bigint "person_id", null: false
    t.bigint "staff_role_id", null: false
    t.date "starts_on", null: false
    t.date "ends_on"
    t.boolean "active", default: true, null: false
    t.text "observations"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "salary_override", precision: 12, scale: 2
    t.index ["person_id"], name: "index_staff_members_on_person_id", unique: true
    t.index ["staff_role_id"], name: "index_staff_members_on_staff_role_id"
  end

  create_table "staff_payments", force: :cascade do |t|
    t.bigint "staff_member_id", null: false
    t.bigint "staff_role_id", null: false
    t.date "period_starts_on", null: false
    t.date "period_ends_on", null: false
    t.decimal "salary", precision: 12, scale: 2, null: false
    t.decimal "overtime_hours", precision: 8, scale: 2, default: "0.0", null: false
    t.decimal "overtime_hour_rate", precision: 10, scale: 2
    t.decimal "overtime_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "goals_bonus", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "extra_bonus", precision: 12, scale: 2, default: "0.0", null: false
    t.string "extra_bonus_reason"
    t.decimal "gross_total", precision: 12, scale: 2, null: false
    t.decimal "advances_total", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "net_total", precision: 12, scale: 2, null: false
    t.date "paid_on", null: false
    t.string "payment_method", null: false
    t.bigint "money_account_id", null: false
    t.text "observations"
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "monthly_salary", precision: 12, scale: 2
    t.decimal "days_worked", precision: 5, scale: 1
    t.index ["created_by_id"], name: "index_staff_payments_on_created_by_id"
    t.index ["money_account_id"], name: "index_staff_payments_on_money_account_id"
    t.index ["staff_member_id", "period_starts_on"], name: "index_staff_payments_on_staff_member_id_and_period_starts_on", unique: true
    t.index ["staff_member_id"], name: "index_staff_payments_on_staff_member_id"
    t.index ["staff_role_id"], name: "index_staff_payments_on_staff_role_id"
  end

  create_table "staff_roles", force: :cascade do |t|
    t.string "name", null: false
    t.decimal "salary", precision: 12, scale: 2
    t.string "pay_frequency"
    t.decimal "overtime_hour_rate", precision: 10, scale: 2
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_staff_roles_on_lower_name", unique: true
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

  create_table "trucks", force: :cascade do |t|
    t.string "plate", null: false
    t.string "brand_model"
    t.string "color"
    t.decimal "capacity_quintals", precision: 8, scale: 2
    t.boolean "own", default: false, null: false
    t.text "observations"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["plate"], name: "index_trucks_on_plate", unique: true
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

  add_foreign_key "account_transfers", "money_accounts", column: "from_account_id"
  add_foreign_key "account_transfers", "money_accounts", column: "to_account_id"
  add_foreign_key "account_transfers", "users", column: "created_by_id"
  add_foreign_key "audit_events", "users", on_delete: :nullify
  add_foreign_key "budgets", "finance_categories"
  add_foreign_key "buyer_advances", "buyers"
  add_foreign_key "buyer_advances", "money_accounts"
  add_foreign_key "buyer_advances", "users", column: "created_by_id"
  add_foreign_key "buyers", "departments"
  add_foreign_key "buyers", "municipalities"
  add_foreign_key "cash_counts", "money_accounts"
  add_foreign_key "cash_counts", "users", column: "created_by_id"
  add_foreign_key "clients", "people"
  add_foreign_key "coffee_conversions", "users", column: "created_by_id"
  add_foreign_key "coffee_conversions", "users", column: "finished_by_id"
  add_foreign_key "coffee_conversions", "users", column: "voided_by_id"
  add_foreign_key "collaborators", "people"
  add_foreign_key "expense_receipts", "expenses"
  add_foreign_key "expenses", "finance_categories"
  add_foreign_key "expenses", "money_accounts"
  add_foreign_key "expenses", "users", column: "created_by_id"
  add_foreign_key "farms", "departments"
  add_foreign_key "farms", "municipalities"
  add_foreign_key "farms", "producers"
  add_foreign_key "finance_categories", "finance_categories", column: "parent_id"
  add_foreign_key "harvest_entries", "payroll_members"
  add_foreign_key "hauler_payments", "haulers"
  add_foreign_key "hauler_payments", "money_accounts"
  add_foreign_key "hauler_payments", "users", column: "created_by_id"
  add_foreign_key "haulers", "people"
  add_foreign_key "invoice_payments", "invoices"
  add_foreign_key "invoice_payments", "money_accounts"
  add_foreign_key "invoice_payments", "users", column: "created_by_id"
  add_foreign_key "invoices", "producers"
  add_foreign_key "invoices", "users", column: "created_by_id"
  add_foreign_key "loan_payments", "loans"
  add_foreign_key "loan_payments", "money_accounts"
  add_foreign_key "loan_payments", "payroll_payment_lines"
  add_foreign_key "loan_payments", "purchases"
  add_foreign_key "loan_payments", "users", column: "created_by_id"
  add_foreign_key "loan_supplies", "loans"
  add_foreign_key "loan_supplies", "supplies"
  add_foreign_key "loans", "money_accounts"
  add_foreign_key "loans", "people"
  add_foreign_key "loans", "users", column: "created_by_id"
  add_foreign_key "municipalities", "departments"
  add_foreign_key "other_incomes", "money_accounts"
  add_foreign_key "other_incomes", "users", column: "created_by_id"
  add_foreign_key "page_visits", "users", on_delete: :cascade
  add_foreign_key "payroll_attendances", "payroll_members"
  add_foreign_key "payroll_expenses", "expense_categories"
  add_foreign_key "payroll_expenses", "money_accounts"
  add_foreign_key "payroll_expenses", "payrolls"
  add_foreign_key "payroll_expenses", "users", column: "created_by_id"
  add_foreign_key "payroll_members", "payroll_roles"
  add_foreign_key "payroll_members", "payrolls"
  add_foreign_key "payroll_members", "people"
  add_foreign_key "payroll_overtimes", "payroll_members"
  add_foreign_key "payroll_payment_lines", "payroll_members"
  add_foreign_key "payroll_payment_lines", "payroll_payments"
  add_foreign_key "payroll_payments", "money_accounts"
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
  add_foreign_key "private_document_prints", "loans", on_delete: :nullify
  add_foreign_key "private_document_prints", "people"
  add_foreign_key "private_document_prints", "private_documents"
  add_foreign_key "private_document_prints", "users"
  add_foreign_key "private_documents", "users", column: "updated_by_id"
  add_foreign_key "producers", "people"
  add_foreign_key "purchase_weighings", "purchases"
  add_foreign_key "purchases", "farms"
  add_foreign_key "purchases", "haulers"
  add_foreign_key "purchases", "invoices"
  add_foreign_key "purchases", "producers"
  add_foreign_key "purchases", "users", column: "created_by_id"
  add_foreign_key "purchases", "users", column: "voided_by_id"
  add_foreign_key "purchases", "zones"
  add_foreign_key "sale_lines", "sales"
  add_foreign_key "sale_lines", "shipments"
  add_foreign_key "sale_payments", "money_accounts"
  add_foreign_key "sale_payments", "sales"
  add_foreign_key "sale_payments", "users", column: "created_by_id"
  add_foreign_key "sales", "buyers"
  add_foreign_key "sales", "users", column: "created_by_id"
  add_foreign_key "sales", "users", column: "voided_by_id"
  add_foreign_key "saved_reports", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "shipment_weighings", "shipments"
  add_foreign_key "shipments", "buyers"
  add_foreign_key "shipments", "carriers"
  add_foreign_key "shipments", "staff_members", column: "driver_id"
  add_foreign_key "shipments", "trucks"
  add_foreign_key "shipments", "users", column: "created_by_id"
  add_foreign_key "shipments", "users", column: "voided_by_id"
  add_foreign_key "staff_advances", "money_accounts"
  add_foreign_key "staff_advances", "staff_members"
  add_foreign_key "staff_advances", "staff_payments"
  add_foreign_key "staff_advances", "users", column: "created_by_id"
  add_foreign_key "staff_attendances", "staff_members"
  add_foreign_key "staff_goals", "staff_members"
  add_foreign_key "staff_goals", "staff_payments"
  add_foreign_key "staff_goals", "users", column: "created_by_id"
  add_foreign_key "staff_members", "people"
  add_foreign_key "staff_members", "staff_roles"
  add_foreign_key "staff_payments", "money_accounts"
  add_foreign_key "staff_payments", "staff_members"
  add_foreign_key "staff_payments", "staff_roles"
  add_foreign_key "staff_payments", "users", column: "created_by_id"
  add_foreign_key "webauthn_credentials", "users"
end
