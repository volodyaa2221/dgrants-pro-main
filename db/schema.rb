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

ActiveRecord::Schema[7.1].define(version: 2015_12_25_143446) do
  create_table "accounts", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "ref_id", default: ""
    t.float "balance", default: 0.0
    t.float "pre_post", default: 0.0
    t.float "remitted", default: 0.0
    t.string "vpd_name", default: ""
    t.string "trial_name", default: ""
    t.integer "sync", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vpd_id"
    t.bigint "trial_id"
    t.index ["id", "trial_id"], name: "index_accounts_on_id_and_trial_id"
    t.index ["id", "vpd_id"], name: "index_accounts_on_id_and_vpd_id"
    t.index ["trial_id"], name: "index_accounts_on_trial_id"
    t.index ["vpd_id"], name: "index_accounts_on_vpd_id"
  end

  create_table "countries", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", default: ""
    t.string "code", default: ""
    t.integer "status", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "currencies", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "code"
    t.string "description"
    t.string "symbol"
    t.float "rate", default: 1.0
    t.integer "status", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "delayed_jobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "priority", default: 0, null: false
    t.integer "attempts", default: 0, null: false
    t.text "handler", null: false
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "forecastings", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "est_start_date"
    t.float "recruitment_rate", default: 0.0
    t.integer "sync", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vpd_id"
    t.bigint "vpd_country_id"
    t.bigint "trial_id"
    t.index ["id", "trial_id"], name: "index_forecastings_on_id_and_trial_id"
    t.index ["id", "vpd_country_id"], name: "index_forecastings_on_id_and_vpd_country_id"
    t.index ["id", "vpd_id"], name: "index_forecastings_on_id_and_vpd_id"
    t.index ["trial_id"], name: "index_forecastings_on_trial_id"
    t.index ["vpd_country_id"], name: "index_forecastings_on_vpd_country_id"
    t.index ["vpd_id"], name: "index_forecastings_on_vpd_id"
  end

  create_table "invoice_files", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.binary "attachment"
    t.bigint "invoice_id"
    t.bigint "passthrough_id"
    t.index ["id", "invoice_id"], name: "index_invoice_files_on_id_and_invoice_id"
    t.index ["id", "passthrough_id"], name: "index_invoice_files_on_id_and_passthrough_id"
    t.index ["invoice_id"], name: "index_invoice_files_on_invoice_id"
    t.index ["passthrough_id"], name: "index_invoice_files_on_passthrough_id"
  end

  create_table "invoice_payment_infos", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "site_address"
    t.string "site_city"
    t.string "site_state"
    t.string "site_country"
    t.string "site_postcode"
    t.string "field2_label"
    t.string "field2_value"
    t.string "field3_label"
    t.string "field3_value"
    t.string "field4_label"
    t.string "field4_value"
    t.string "field5_label"
    t.string "field5_value"
    t.string "field6_label"
    t.string "field6_value"
    t.string "bank_street_address"
    t.string "bank_city"
    t.string "bank_state"
    t.string "bank_country"
    t.string "bank_postcode"
    t.bigint "invoice_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "field1_label"
    t.string "field1_value"
    t.string "currency_code"
    t.string "bank_name"
    t.index ["invoice_id"], name: "index_invoice_payment_infos_on_invoice_id"
  end

  create_table "invoices", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "invoice_no"
    t.float "amount", default: 0.0
    t.float "included_tax", default: 0.0
    t.float "withholding", default: 0.0
    t.float "overhead", default: 0.0
    t.float "usd_rate", default: 1.0
    t.datetime "pay_at"
    t.datetime "sent_at"
    t.integer "type", default: 0
    t.string "pi_dea"
    t.string "drugdev_dea"
    t.integer "status", default: 0
    t.integer "sync", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vpd_id"
    t.bigint "vpd_currency_id"
    t.bigint "site_id"
    t.bigint "transfer_id"
    t.bigint "account_id"
    t.bigint "currency_id"
    t.index ["account_id"], name: "index_invoices_on_account_id"
    t.index ["currency_id"], name: "index_invoices_on_currency_id"
    t.index ["id", "account_id"], name: "index_invoices_on_id_and_account_id"
    t.index ["id", "currency_id"], name: "index_invoices_on_id_and_currency_id"
    t.index ["id", "site_id"], name: "index_invoices_on_id_and_site_id"
    t.index ["id", "transfer_id"], name: "index_invoices_on_id_and_transfer_id"
    t.index ["id", "vpd_currency_id"], name: "index_invoices_on_id_and_vpd_currency_id"
    t.index ["id", "vpd_id"], name: "index_invoices_on_id_and_vpd_id"
    t.index ["site_id"], name: "index_invoices_on_site_id"
    t.index ["transfer_id"], name: "index_invoices_on_transfer_id"
    t.index ["vpd_currency_id"], name: "index_invoices_on_vpd_currency_id"
    t.index ["vpd_id"], name: "index_invoices_on_vpd_id"
  end

  create_table "passthroughs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "budget_name"
    t.string "description"
    t.float "amount", default: 0.0
    t.datetime "happened_at"
    t.integer "status", default: 1
    t.integer "sync", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vpd_id"
    t.bigint "site_id"
    t.bigint "site_passthrough_budget_id"
    t.index ["id", "site_id"], name: "index_passthroughs_on_id_and_site_id"
    t.index ["id", "site_passthrough_budget_id"], name: "index_passthroughs_on_id_and_site_passthrough_budget_id"
    t.index ["id", "vpd_id"], name: "index_passthroughs_on_id_and_vpd_id"
    t.index ["site_id"], name: "index_passthroughs_on_site_id"
    t.index ["site_passthrough_budget_id"], name: "index_passthroughs_on_site_passthrough_budget_id"
    t.index ["vpd_id"], name: "index_passthroughs_on_vpd_id"
  end

  create_table "payment_infos", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "country"
    t.string "field1_label"
    t.string "field1_value"
    t.string "field2_label"
    t.string "field2_value"
    t.string "field3_label"
    t.string "field3_value"
    t.string "field4_label"
    t.string "field4_value"
    t.string "field5_label"
    t.string "field5_value"
    t.string "field6_label"
    t.string "field6_value"
    t.string "bank_name"
    t.string "bank_street_address"
    t.string "bank_city"
    t.string "bank_state"
    t.string "bank_postcode"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "site_id"
    t.string "currency_code"
    t.index ["site_id"], name: "index_payment_infos_on_site_id"
  end

  create_table "posts", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "post_id"
    t.float "amount", default: 0.0
    t.integer "type", default: 0
    t.integer "sync", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vpd_id"
    t.bigint "account_id"
    t.bigint "invoice_id"
    t.index ["account_id"], name: "index_posts_on_account_id"
    t.index ["id", "account_id"], name: "index_posts_on_id_and_account_id"
    t.index ["id", "invoice_id"], name: "index_posts_on_id_and_invoice_id"
    t.index ["id", "vpd_id"], name: "index_posts_on_id_and_vpd_id"
    t.index ["invoice_id"], name: "index_posts_on_invoice_id"
    t.index ["vpd_id"], name: "index_posts_on_vpd_id"
  end

  create_table "roles", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "role"
    t.datetime "invitation_sent_date"
    t.integer "status", default: 1
    t.integer "sync", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.integer "rolify_id"
    t.string "rolify_type"
    t.bigint "vpd_id"
    t.index ["id", "user_id"], name: "index_roles_on_id_and_user_id"
    t.index ["id", "vpd_id"], name: "index_roles_on_id_and_vpd_id"
    t.index ["rolify_id"], name: "index_roles_on_rolify_id"
    t.index ["user_id"], name: "index_roles_on_user_id"
    t.index ["vpd_id"], name: "index_roles_on_vpd_id"
  end

  create_table "site_entries", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "event_id", default: ""
    t.integer "type", default: 0
    t.float "amount", default: 0.0, null: false
    t.float "tax_rate", default: 0.0, null: false
    t.float "holdback_rate", default: 0.0, null: false
    t.float "advance", default: 0.0, null: false
    t.integer "event_cap"
    t.integer "event_count", default: 0
    t.datetime "start_date"
    t.datetime "end_date"
    t.integer "status", default: 2
    t.integer "sync", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.bigint "vpd_id"
    t.bigint "vpd_ledger_category_id"
    t.bigint "site_id"
    t.index ["id", "site_id"], name: "index_site_entries_on_id_and_site_id"
    t.index ["id", "user_id"], name: "index_site_entries_on_id_and_user_id"
    t.index ["id", "vpd_id"], name: "index_site_entries_on_id_and_vpd_id"
    t.index ["id", "vpd_ledger_category_id"], name: "index_site_entries_on_id_and_vpd_ledger_category_id"
    t.index ["site_id"], name: "index_site_entries_on_site_id"
    t.index ["user_id"], name: "index_site_entries_on_user_id"
    t.index ["vpd_id"], name: "index_site_entries_on_vpd_id"
    t.index ["vpd_ledger_category_id"], name: "index_site_entries_on_vpd_ledger_category_id"
  end

  create_table "site_events", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "event_id", default: ""
    t.integer "type", default: 0
    t.string "description", default: ""
    t.string "patient_id"
    t.datetime "happened_at"
    t.string "happened_at_text"
    t.string "source", default: "Manual"
    t.integer "status", default: 1
    t.integer "sync", default: 2
    t.string "author"
    t.string "co_author"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vpd_id"
    t.bigint "trial_event_id"
    t.bigint "site_id"
    t.string "event_log_id"
    t.boolean "approved", default: true
    t.index ["id", "site_id"], name: "index_site_events_on_id_and_site_id"
    t.index ["id", "trial_event_id"], name: "index_site_events_on_id_and_trial_event_id"
    t.index ["id", "vpd_id"], name: "index_site_events_on_id_and_vpd_id"
    t.index ["site_id"], name: "index_site_events_on_site_id"
    t.index ["trial_event_id"], name: "index_site_events_on_trial_event_id"
    t.index ["vpd_id"], name: "index_site_events_on_vpd_id"
  end

  create_table "site_passthrough_budgets", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.float "max_amount", default: 0.0, null: false
    t.float "monthly_amount", default: 0.0, null: false
    t.integer "status", default: 2
    t.integer "sync", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vpd_id"
    t.bigint "site_id"
    t.index ["id", "site_id"], name: "index_site_passthrough_budgets_on_id_and_site_id"
    t.index ["id", "vpd_id"], name: "index_site_passthrough_budgets_on_id_and_vpd_id"
    t.index ["site_id"], name: "index_site_passthrough_budgets_on_site_id"
    t.index ["vpd_id"], name: "index_site_passthrough_budgets_on_vpd_id"
  end

  create_table "site_schedules", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.boolean "mode", default: true
    t.float "tax_rate", default: 0.0
    t.float "withholding_rate", default: 0.0
    t.float "overhead_rate", default: 0.0
    t.float "holdback_rate", default: 0.0
    t.float "holdback_amount"
    t.integer "payment_terms", default: 30
    t.integer "status", default: 1
    t.integer "sync", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vpd_id"
    t.bigint "vpd_currency_id"
    t.bigint "site_id"
    t.bigint "currency_id"
    t.bigint "trial_schedule_id"
    t.index ["currency_id"], name: "index_site_schedules_on_currency_id"
    t.index ["id", "currency_id"], name: "index_site_schedules_on_id_and_currency_id"
    t.index ["id", "site_id"], name: "index_site_schedules_on_id_and_site_id"
    t.index ["id", "trial_schedule_id"], name: "index_site_schedules_on_id_and_trial_schedule_id"
    t.index ["id", "vpd_currency_id"], name: "index_site_schedules_on_id_and_vpd_currency_id"
    t.index ["id", "vpd_id"], name: "index_site_schedules_on_id_and_vpd_id"
    t.index ["site_id"], name: "index_site_schedules_on_site_id"
    t.index ["trial_schedule_id"], name: "index_site_schedules_on_trial_schedule_id"
    t.index ["vpd_currency_id"], name: "index_site_schedules_on_vpd_currency_id"
    t.index ["vpd_id"], name: "index_site_schedules_on_vpd_id"
  end

  create_table "sites", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", default: ""
    t.string "site_id", default: ""
    t.integer "site_type"
    t.string "city"
    t.string "state"
    t.string "state_code"
    t.string "address"
    t.string "zip_code"
    t.string "pi_first_name"
    t.string "pi_last_name"
    t.string "pi_dea"
    t.string "drugdev_dea"
    t.string "country_name"
    t.datetime "start_date"
    t.integer "payment_verified", default: 0
    t.integer "status", default: 1
    t.integer "sync", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vpd_id"
    t.bigint "vpd_country_id"
    t.bigint "trial_id"
    t.integer "main_site_id"
    t.bigint "country_id"
    t.integer "is_invoice_overdue", default: 0
    t.index ["country_id"], name: "index_sites_on_country_id"
    t.index ["id", "country_id"], name: "index_sites_on_id_and_country_id"
    t.index ["id", "trial_id"], name: "index_sites_on_id_and_trial_id"
    t.index ["id", "vpd_country_id"], name: "index_sites_on_id_and_vpd_country_id"
    t.index ["id", "vpd_id"], name: "index_sites_on_id_and_vpd_id"
    t.index ["main_site_id"], name: "index_sites_on_main_site_id"
    t.index ["trial_id"], name: "index_sites_on_trial_id"
    t.index ["vpd_country_id"], name: "index_sites_on_vpd_country_id"
    t.index ["vpd_id"], name: "index_sites_on_vpd_id"
  end

  create_table "sponsors", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", default: ""
    t.integer "status", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "transactions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "transaction_id"
    t.integer "type", default: 0
    t.string "type_id", default: ""
    t.string "patient_id"
    t.datetime "happened_at"
    t.boolean "payable", default: false
    t.float "amount", default: 0.0
    t.float "tax", default: 0.0
    t.float "earned", default: 0.0
    t.float "advance", default: 0.0
    t.float "retained_amount", default: 0.0
    t.float "retained_tax", default: 0.0
    t.float "retained", default: 0.0
    t.float "withholding", default: 0.0
    t.float "usd_rate", default: 1.0
    t.boolean "paid", default: false
    t.string "source", default: "Manual"
    t.integer "status", default: 2
    t.integer "included", default: 1
    t.integer "sync", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vpd_id"
    t.bigint "site_id"
    t.bigint "site_entry_id"
    t.bigint "site_event_id"
    t.bigint "site_passthrough_budget_id"
    t.bigint "invoice_id"
    t.bigint "passthrough_id"
    t.index ["id", "invoice_id"], name: "index_transactions_on_id_and_invoice_id"
    t.index ["id", "passthrough_id"], name: "index_transactions_on_id_and_passthrough_id"
    t.index ["id", "site_entry_id"], name: "index_transactions_on_id_and_site_entry_id"
    t.index ["id", "site_event_id"], name: "index_transactions_on_id_and_site_event_id"
    t.index ["id", "site_id"], name: "index_transactions_on_id_and_site_id"
    t.index ["id", "site_passthrough_budget_id"], name: "index_transactions_on_id_and_site_passthrough_budget_id"
    t.index ["id", "vpd_id"], name: "index_transactions_on_id_and_vpd_id"
    t.index ["invoice_id"], name: "index_transactions_on_invoice_id"
    t.index ["passthrough_id"], name: "index_transactions_on_passthrough_id"
    t.index ["site_entry_id"], name: "index_transactions_on_site_entry_id"
    t.index ["site_event_id"], name: "index_transactions_on_site_event_id"
    t.index ["site_id"], name: "index_transactions_on_site_id"
    t.index ["site_passthrough_budget_id"], name: "index_transactions_on_site_passthrough_budget_id"
    t.index ["vpd_id"], name: "index_transactions_on_vpd_id"
  end

  create_table "transfers", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "transfer_id", default: ""
    t.string "description", default: ""
    t.float "amount", default: 0.0
    t.integer "type", default: 0
    t.integer "status", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "trial_entries", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "event_id", default: ""
    t.integer "type", default: 0
    t.float "amount", default: 0.0, null: false
    t.float "tax_rate", default: 0.0, null: false
    t.float "holdback_rate", default: 0.0, null: false
    t.float "advance", default: 0.0, null: false
    t.integer "event_cap"
    t.datetime "start_date"
    t.datetime "end_date"
    t.integer "status", default: 1
    t.integer "sync", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vpd_id"
    t.bigint "vpd_ledger_category_id"
    t.bigint "trial_schedule_id"
    t.bigint "user_id"
    t.index ["id", "trial_schedule_id"], name: "index_trial_entries_on_id_and_trial_schedule_id"
    t.index ["id", "user_id"], name: "index_trial_entries_on_id_and_user_id"
    t.index ["id", "vpd_id"], name: "index_trial_entries_on_id_and_vpd_id"
    t.index ["id", "vpd_ledger_category_id"], name: "index_trial_entries_on_id_and_vpd_ledger_category_id"
    t.index ["trial_schedule_id"], name: "index_trial_entries_on_trial_schedule_id"
    t.index ["user_id"], name: "index_trial_entries_on_user_id"
    t.index ["vpd_id"], name: "index_trial_entries_on_vpd_id"
    t.index ["vpd_ledger_category_id"], name: "index_trial_entries_on_vpd_ledger_category_id"
  end

  create_table "trial_events", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "event_id", default: ""
    t.integer "type", default: 0
    t.string "description", default: ""
    t.integer "days", default: 0, null: false
    t.boolean "editable", default: true
    t.integer "status", default: 1
    t.integer "sync", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vpd_id"
    t.bigint "vpd_event_id"
    t.bigint "trial_id"
    t.integer "dependency_id"
    t.integer "order"
    t.index ["dependency_id"], name: "index_trial_events_on_dependency_id"
    t.index ["id", "trial_id"], name: "index_trial_events_on_id_and_trial_id"
    t.index ["id", "vpd_event_id"], name: "index_trial_events_on_id_and_vpd_event_id"
    t.index ["id", "vpd_id"], name: "index_trial_events_on_id_and_vpd_id"
    t.index ["trial_id"], name: "index_trial_events_on_trial_id"
    t.index ["vpd_event_id"], name: "index_trial_events_on_vpd_event_id"
    t.index ["vpd_id"], name: "index_trial_events_on_vpd_id"
  end

  create_table "trial_passthrough_budgets", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.float "max_amount", default: 0.0, null: false
    t.float "monthly_amount", default: 0.0, null: false
    t.integer "status", default: 1
    t.integer "sync", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vpd_id"
    t.bigint "trial_schedule_id"
    t.index ["id", "trial_schedule_id"], name: "index_trial_passthrough_budgets_on_id_and_trial_schedule_id"
    t.index ["id", "vpd_id"], name: "index_trial_passthrough_budgets_on_id_and_vpd_id"
    t.index ["trial_schedule_id"], name: "index_trial_passthrough_budgets_on_trial_schedule_id"
    t.index ["vpd_id"], name: "index_trial_passthrough_budgets_on_vpd_id"
  end

  create_table "trial_schedules", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.float "tax_rate", default: 0.0
    t.float "withholding_rate", default: 0.0
    t.float "overhead_rate", default: 0.0
    t.float "holdback_rate", default: 0.0
    t.float "holdback_amount"
    t.integer "payment_terms", default: 30
    t.integer "status", default: 1
    t.integer "sync", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vpd_id"
    t.bigint "vpd_currency_id"
    t.bigint "trial_id"
    t.bigint "currency_id"
    t.index ["currency_id"], name: "index_trial_schedules_on_currency_id"
    t.index ["id", "currency_id"], name: "index_trial_schedules_on_id_and_currency_id"
    t.index ["id", "trial_id"], name: "index_trial_schedules_on_id_and_trial_id"
    t.index ["id", "vpd_currency_id"], name: "index_trial_schedules_on_id_and_vpd_currency_id"
    t.index ["id", "vpd_id"], name: "index_trial_schedules_on_id_and_vpd_id"
    t.index ["trial_id"], name: "index_trial_schedules_on_trial_id"
    t.index ["vpd_currency_id"], name: "index_trial_schedules_on_vpd_currency_id"
    t.index ["vpd_id"], name: "index_trial_schedules_on_vpd_id"
  end

  create_table "trials", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "title", default: ""
    t.string "trial_id"
    t.string "ctgov_nct"
    t.integer "indication"
    t.integer "phase"
    t.integer "status", default: 1
    t.integer "max_patients"
    t.integer "real_patients_count", default: 0
    t.integer "patients_count", default: 0
    t.boolean "should_forecast", default: false
    t.boolean "forecasting_now", default: false
    t.integer "sync", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vpd_id"
    t.bigint "vpd_sponsor_id"
    t.bigint "sponsor_id"
    t.integer "event_log_mode", default: 1
    t.index ["id", "sponsor_id"], name: "index_trials_on_id_and_sponsor_id"
    t.index ["id", "vpd_id"], name: "index_trials_on_id_and_vpd_id"
    t.index ["id", "vpd_sponsor_id"], name: "index_trials_on_id_and_vpd_sponsor_id"
    t.index ["sponsor_id"], name: "index_trials_on_sponsor_id"
    t.index ["vpd_id"], name: "index_trials_on_vpd_id"
    t.index ["vpd_sponsor_id"], name: "index_trials_on_vpd_sponsor_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name", default: ""
    t.string "last_name", default: ""
    t.string "title", default: ""
    t.string "prdisplay", default: "P"
    t.string "curr_pref", default: "USD"
    t.string "salutation", default: "Mr."
    t.string "organization", default: ""
    t.string "position", default: ""
    t.string "phone", default: ""
    t.string "country", default: ""
    t.integer "member_type", default: 100
    t.integer "role_type", default: 100
    t.integer "status", default: 1
    t.string "authentication_token"
    t.string "profile_id"
    t.string "invited_to_type"
    t.integer "invited_to_id"
    t.boolean "immediate_to_confirm", default: false
    t.integer "manager_id"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["manager_id"], name: "index_users_on_manager_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "vpd_approvers", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "type", default: 0
    t.integer "status", default: 1
    t.integer "sync", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.bigint "vpd_id"
    t.bigint "role_id"
    t.index ["id", "role_id"], name: "index_vpd_approvers_on_id_and_role_id"
    t.index ["id", "user_id"], name: "index_vpd_approvers_on_id_and_user_id"
    t.index ["id", "vpd_id"], name: "index_vpd_approvers_on_id_and_vpd_id"
    t.index ["role_id"], name: "index_vpd_approvers_on_role_id"
    t.index ["user_id"], name: "index_vpd_approvers_on_user_id"
    t.index ["vpd_id"], name: "index_vpd_approvers_on_vpd_id"
  end

  create_table "vpd_countries", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", default: ""
    t.string "code", default: ""
    t.integer "status", default: 1
    t.integer "sync", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vpd_id"
    t.bigint "country_id"
    t.index ["country_id"], name: "index_vpd_countries_on_country_id"
    t.index ["id", "country_id"], name: "index_vpd_countries_on_id_and_country_id"
    t.index ["id", "vpd_id"], name: "index_vpd_countries_on_id_and_vpd_id"
    t.index ["vpd_id"], name: "index_vpd_countries_on_vpd_id"
  end

  create_table "vpd_currencies", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "code"
    t.string "description"
    t.string "symbol", default: ""
    t.float "rate"
    t.integer "status", default: 1
    t.integer "sync", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vpd_id"
    t.bigint "currency_id"
    t.index ["currency_id"], name: "index_vpd_currencies_on_currency_id"
    t.index ["id", "currency_id"], name: "index_vpd_currencies_on_id_and_currency_id"
    t.index ["id", "vpd_id"], name: "index_vpd_currencies_on_id_and_vpd_id"
    t.index ["vpd_id"], name: "index_vpd_currencies_on_vpd_id"
  end

  create_table "vpd_events", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "event_id", default: ""
    t.integer "type", default: 0
    t.string "description", default: ""
    t.integer "days", default: 0, null: false
    t.integer "status", default: 1
    t.integer "sync", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vpd_id"
    t.integer "dependency_id"
    t.integer "order"
    t.index ["dependency_id"], name: "index_vpd_events_on_dependency_id"
    t.index ["id", "vpd_id"], name: "index_vpd_events_on_id_and_vpd_id"
    t.index ["vpd_id"], name: "index_vpd_events_on_vpd_id"
  end

  create_table "vpd_ledger_categories", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", default: ""
    t.integer "status", default: 1
    t.integer "sync", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vpd_id"
    t.index ["id", "vpd_id"], name: "index_vpd_ledger_categories_on_id_and_vpd_id"
    t.index ["vpd_id"], name: "index_vpd_ledger_categories_on_vpd_id"
  end

  create_table "vpd_mail_templates", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "type"
    t.string "subject"
    t.text "body"
    t.integer "status", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vpd_id"
    t.index ["id", "vpd_id"], name: "index_vpd_mail_templates_on_id_and_vpd_id"
    t.index ["vpd_id"], name: "index_vpd_mail_templates_on_vpd_id"
  end

  create_table "vpd_reports", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name"
    t.string "url"
    t.integer "status", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vpd_id"
    t.index ["id", "vpd_id"], name: "index_vpd_reports_on_id_and_vpd_id"
    t.index ["vpd_id"], name: "index_vpd_reports_on_vpd_id"
  end

  create_table "vpd_sponsors", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", default: ""
    t.integer "status", default: 1
    t.integer "sync", default: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "vpd_id"
    t.bigint "sponsor_id"
    t.index ["id", "sponsor_id"], name: "index_vpd_sponsors_on_id_and_sponsor_id"
    t.index ["id", "vpd_id"], name: "index_vpd_sponsors_on_id_and_vpd_id"
    t.index ["sponsor_id"], name: "index_vpd_sponsors_on_sponsor_id"
    t.index ["vpd_id"], name: "index_vpd_sponsors_on_vpd_id"
  end

  create_table "vpds", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", default: ""
    t.float "auto_amount", default: 0.0
    t.float "tier1_amount"
    t.string "db_host"
    t.string "db_name"
    t.string "username"
    t.string "password"
    t.string "trial_dashboard"
    t.string "site_dashboard"
    t.integer "status", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
