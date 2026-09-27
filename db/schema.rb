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

ActiveRecord::Schema[8.1].define(version: 2026_09_27_185409) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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
    t.index ["created_by_id"], name: "index_invoices_on_created_by_id"
    t.index ["number"], name: "index_invoices_on_number", unique: true
    t.index ["payment_status"], name: "index_invoices_on_payment_status"
    t.index ["producer_id"], name: "index_invoices_on_producer_id"
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
    t.index ["department_id"], name: "index_people_on_department_id"
    t.index ["dni"], name: "index_people_on_dni", unique: true, where: "(dni IS NOT NULL)"
    t.index ["last_names", "first_names"], name: "index_people_on_last_names_and_first_names"
    t.index ["municipality_id"], name: "index_people_on_municipality_id"
    t.index ["rtn"], name: "index_people_on_rtn", unique: true, where: "(rtn IS NOT NULL)"
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
    t.bigint "zone_id"
    t.string "kind", null: false
    t.string "farm_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id"], name: "index_producers_on_person_id", unique: true
    t.index ["zone_id"], name: "index_producers_on_zone_id"
  end

  create_table "purchases", force: :cascade do |t|
    t.date "purchased_on", null: false
    t.bigint "producer_id", null: false
    t.bigint "zone_id"
    t.bigint "invoice_id"
    t.bigint "created_by_id", null: false
    t.string "coffee_state", null: false
    t.decimal "gross_weight", precision: 10, scale: 2, null: false
    t.decimal "humidity_percent", precision: 5, scale: 2, null: false
    t.decimal "price_per_pound", precision: 10, scale: 2, null: false
    t.decimal "sacks", precision: 10, scale: 4, null: false
    t.decimal "tare", precision: 10, scale: 2, null: false
    t.decimal "net_weight", precision: 12, scale: 2, null: false
    t.decimal "total", precision: 14, scale: 2, null: false
    t.text "observations"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_purchases_on_created_by_id"
    t.index ["invoice_id"], name: "index_purchases_on_invoice_id"
    t.index ["producer_id"], name: "index_purchases_on_producer_id"
    t.index ["purchased_on"], name: "index_purchases_on_purchased_on"
    t.index ["zone_id"], name: "index_purchases_on_zone_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.boolean "admin", default: false, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "zones", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((name)::text)", name: "index_zones_on_lower_name", unique: true
  end

  add_foreign_key "clients", "people"
  add_foreign_key "collaborators", "people"
  add_foreign_key "invoices", "producers"
  add_foreign_key "invoices", "users", column: "created_by_id"
  add_foreign_key "municipalities", "departments"
  add_foreign_key "people", "departments"
  add_foreign_key "people", "municipalities"
  add_foreign_key "permissions", "users"
  add_foreign_key "producers", "people"
  add_foreign_key "producers", "zones"
  add_foreign_key "purchases", "invoices"
  add_foreign_key "purchases", "producers"
  add_foreign_key "purchases", "users", column: "created_by_id"
  add_foreign_key "purchases", "zones"
  add_foreign_key "sessions", "users"
end
