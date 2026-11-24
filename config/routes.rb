Rails.application.routes.draw do
  resource :session, only: %i[ new create destroy ]
  # Signing in with a fingerprint (passkeys, WebAuthn): one more way in.
  resource :passkey_session, only: :create do
    post :options
  end
  # Password recovery by email is disconnected until there is an email
  # service. Admins reset passwords from the panel instead.
  # resources :passwords, param: :token

  root "dashboard#show"
  # The business's logo, public (the sign-in page shows it too).
  resource :site_logo, only: :show
  # Profile photos of people and users, for signed-in users.
  resources :profile_photos, only: :show
  # The signed-in user's own display settings (modal or drawer, navigation).
  resource :user_setting, only: %i[ edit update ]
  resources :webauthn_credentials, only: %i[ create destroy ] do
    post :options, on: :collection
  end
  # Coffee futures on the exchange, for the home page card.
  resource :coffee_market, only: :show
  # The home page's pending work in detail, with the way to solve each.
  resource :pending_work, only: :show, controller: "pending_work"
  # What a searchable picker finds as the user types (JSON, PickerSearch).
  get "picker_search/:kind", to: "picker_searches#show", as: :picker_search, defaults: { format: :json }
  # A person's panel, opened by putting a finger on the reader (Fernando,
  # 2026-11-14), and what a page needs to fill its fields with that person.
  resources :person_panels, only: :show, path: "people/panel"
  # Who looks like the person being written (Fernando, 2026-11-18).
  resource :person_duplicates, only: :show, path: "people/duplicates"
  resources :fingerprint_matches, only: :show, defaults: { format: :json }
  # The fingerprint bridge of a PC (tools/fingerprint_bridge): pairing with
  # a one-time code and the templates it identifies with.
  namespace :fingerprint_bridge do
    resource :pairing, only: :create
    resource :templates, only: :show
  end

  namespace :administration do
    root "home#index"
    resources :people do
      # Merge another person into this one (Fernando, 2026-10-14).
      resource :merge, only: %i[ new create ], controller: "person_merges"
      # Its fingerprints (Fernando, 2026-11-14): administrators only.
      resources :fingerprints, only: %i[ new create show destroy ]
    end
    # The PCs with a fingerprint reader.
    resources :fingerprint_stations, except: %i[ edit update ] do
      member do
        patch :link
        post :pairing
      end
    end
    resources :producers, only: %i[ edit update ]
    resources :farms
    resources :zones, except: :show
    resources :audit_events, only: %i[ index show ]
    resource :site_setting, only: %i[ show edit update ]
    # The promissory note and the loan contract: two fixed documents to edit.
    resources :private_documents, only: %i[ index show edit update ]
    # The data backup: a .zip with the database dump and a CSV per table.
    resource :backup, only: %i[ show create ]
    # Centro de control (only User::DATA_EXPORTER_ID): the developments
    # quoted apart (PaidFeature) and the data maintenance tasks.
    resource :control_center, only: :show
    # The day closed for the whole business (Fernando, 2026-11-18).
    resources :day_closes, only: %i[ index create ], controller: "business_day_closes" do
      member { patch :reopen }
    end
    resource :control_setting, only: :update
    resources :paid_features, only: :update
    # Data maintenance tasks (Maintenance, only User::DATA_EXPORTER_ID).
    resources :maintenance_runs, path: "maintenance/runs", only: %i[ create show ] do
      member { post :revert }
    end
    resources :maintenance_tasks, path: "maintenance", only: %i[ index show ], param: :slug
    resources :users, only: %i[ index show new create edit update ] do
      member do
        get :reset_password, action: :edit_password
        patch :reset_password
      end
    end
  end

  namespace :trading do
    # Producers that stopped selling (Fernando, 2026-11-13): the Inicio's card and the whole list.
    resources :idle_producers, only: :index do
      get :card, on: :collection
    end
    root "home#index"
    resources :purchases do
      patch :void, on: :member
      # Pay the producer's loans with this purchase ("pago con café").
      resource :loan_settlement, only: %i[ new create ]
    end
    resources :invoices, only: %i[ index show new create ] do
      # Administrators void it, even paid (Fernando, 2026-11-12).
      resource :void, only: %i[ new create ], controller: "invoice_voids"
      # Payments to the producer ("abonos"), each with its receipt.
      resources :payments, only: %i[ new create show destroy ], controller: "invoice_payments"
    end
    resources :producers, except: :destroy
    # The card beside the purchase form: the producer picked, at a glance.
    resources :producer_cards, only: :show
    # Carreros: their commissions and the payments of them, each with its receipt.
    resources :haulers, except: :destroy do
      resources :payments, only: %i[ new create show destroy ], controller: "hauler_payments"
    end
    resources :zones, only: %i[ index new create edit update ]
    resource :daily_close, only: :show
  end

  # Comercialización (Fernando, 2026-10-23): vehicles leave with coffee for a
  # buyer, are weighed again there, and are sold and collected.
  namespace :sales do
    root "home#index"
    # «Nueva salida»: to sell, to process or to another warehouse.
    resource :departure, only: :new
    # The driver's card beside the shipment form (Fernando, 2026-11-13).
    resources :driver_cards, only: :show
    # Lots of purchased coffee (Fernando, 2026-11-13): shares of purchase
    # invoices that go on the shipments. Before the shipments: "lots" is no id.
    resources :coffee_batches, path: "shipments/lots" do
      resources :invoices, only: %i[ new create destroy ], controller: "coffee_batch_invoices"
      resources :conversions, only: :destroy, controller: "coffee_batch_conversions"
      # Closed without a shipment or a process (Fernando, 2026-11-22).
      resource :closing, only: %i[ new create destroy ], controller: "coffee_batch_closings"
    end
    resources :shipments, except: :destroy do
      patch :void, on: :member
      # Weighed on the buyer's scale.
      resource :arrival, only: %i[ edit update ]
      # Removes one of its scales (Fernando, 2026-11-15).
      delete "scales/:side", to: "shipment_scales#destroy", as: :scale, constraints: { side: /origin|destination/ }
      # Its remission, to print (as the client's booklet).
      resource :remission, only: :show
      # Why a difference passes its tolerance (Fernando, 2026-11-18): also closed.
      resource :reasons, only: %i[ edit update ], controller: "shipment_reasons"
      # What it cost (Fernando, 2026-11-12): its lots (2026-11-13), costs
      # registered from it and expenses of Control financiero assigned to it.
      resources :batches, only: %i[ new create destroy ], controller: "shipment_batches"
      resources :costs, only: %i[ new create destroy ], controller: "shipment_costs"
      resources :expenses, only: %i[ new create destroy ], controller: "shipment_expenses"
    end
    resources :sales, only: %i[ index show new create ] do
      patch :void, on: :member
      # The buyer's settlement: what it pays per its own liquidation.
      resource :settlement, only: %i[edit update], controller: "sale_settlements"
      # What the buyer pays ("cobros"), each with its receipt.
      resources :payments, only: %i[ new create show destroy ], controller: "sale_payments"
    end
    resources :buyers, except: :destroy do
      # Advances the buyer gives, paid back with coffee.
      resources :buyer_advances, path: "advances", only: %i[ new create show destroy ] do
        # Given back in money (Fernando, 2026-11-16).
        resources :refunds, controller: "buyer_advance_refunds", only: %i[ new create destroy ]
      end
    end
    # Every advance of buyers and banks, and a new one of any of them.
    resources :buyer_advances, path: "advances", only: %i[ index new create ]
    # An advance applied to sales by a % of it (from the advance or from the sale).
    resources :advance_applications, controller: "buyer_advance_sales", only: %i[ new create destroy ]
    resources :carriers, except: :destroy
    resources :vehicles, except: :destroy
    # Camión, pick-up…: the kinds of vehicle.
    resources :vehicle_types, only: %i[ index new create edit update ]
    resources :warehouses
    # Where coffee is processed.
    resources :processing_sites, path: "sites", except: :destroy
    # Coffee moved from one warehouse to another.
    resources :warehouse_transfers, path: "transfers", only: %i[ index show new create ] do
      patch :void, on: :member
    end
    resource :stock, only: :show
    # Physical counts with their adjustment, and the day's reconciliation (Fernando, 2026-11-18).
    # «Cuadrar inventario»: every state of every warehouse at once (Fernando, 2026-11-23).
    resource :stock_square, path: "counts/square", only: %i[ new create ]
    resources :stock_counts, path: "counts", only: %i[ index show new create ] do
      patch :void, on: :member
    end
    resource :stock_reconciliation, path: "reconciliation", only: :show
    # Insumos (Fernando, 2026-11-12/13): the inventory (what came in, what the
    # loans took and what was delivered), each entry with its investment,
    # what is still to deliver and the catalog (from Préstamos).
    scope "supplies" do
      get "/", to: "supply_stocks#show", as: :supply_stock
      resources :supply_entries, path: "entries", only: %i[ new create show destroy ]
      resources :supply_deliveries, path: "deliveries", only: %i[ index update destroy ]
      resources :supply_exits, path: "exits", only: %i[ index new create show destroy ]
      resources :supplies, path: "catalog", only: %i[ index new create edit update ]
      # Fuel and oil of the business dispatched to the vehicles (Fernando, 2026-11-22).
      resource :fuel_dispatches, path: "fuel", only: :show
    end
    # One coffee state of the stock (or all: "total"), lot by lot.
    get "stock/:coffee_state", to: "stock_states#show", as: :stock_state,
                               constraints: { coffee_state: /cherry|wet_parchment|dry_parchment|total/ }
    # Why its net pounds and sacks are not the expected ones (administrators).
    get "stock/:coffee_state/check", to: "stock_checks#show", as: :stock_check,
                                     constraints: { coffee_state: /cherry|wet_parchment|dry_parchment/ }
    # Coffee converted to the next state: weighed first, its result later.
    resources :coffee_conversions, path: "conversions", only: %i[ index show new create ] do
      member do
        patch :void
        patch :reopen
      end
      resource :result, only: %i[ edit update ], controller: "conversion_results"
      # What processing it cost.
      resources :costs, only: %i[ new create destroy ], controller: "processing_costs"
    end
    resource :daily_close, only: :show
  end

  # Control financiero (Fernando, 2026-10-23): every money outflow of the
  # business, its accounts, categories and budget.
  namespace :finance do
    root "home#index"
    resources :movements, only: :index
    resources :incomes, only: :index
    resources :expenses, defaults: { kind: "expense" }
    resources :investments, controller: "expenses", defaults: { kind: "investment" }
    # The receipt's photo or PDF of an expense.
    resources :expense_receipts, only: :show
    # Before :money_accounts, so «opening» is not taken for an id.
    # The opening balances, guided (Fernando, 2026-11-18).
    resources :opening_balances, only: %i[ index update ], path: "money_accounts/opening"
    resources :money_accounts, except: :destroy
    resources :account_transfers, only: %i[ new create destroy ]
    resources :other_incomes, only: %i[ new create destroy ]
    # Cash counts ("arqueos"): what was counted against the system's balance.
    resources :cash_counts, only: %i[ new create destroy ]
    # «Cuadrar cuentas»: every active account at once (Fernando, 2026-11-23).
    resource :account_square, path: "accounts/square", only: %i[ new create ]
    resources :categories, only: %i[ index new create edit update ]
    resource :budget, only: %i[ show update ]
    # Giving an account to what was registered without one.
    resource :consolidation, only: %i[ show update ]
    # The business's own payroll (Planilla interna): roles and employees,
    # each with their payments by period, advances and goals.
    resources :staff_roles, path: "staff/roles", only: %i[ index new create edit update destroy ]
    # The payroll sheet: fortnight (with its attendance), month and history.
    resource :staff_sheet, path: "staff/sheet", only: %i[ show update ] do
      post :pay
    end
    # The owners' loans from a bank or another person (a development quoted apart, PaidFeature).
    resources :owner_loans, path: "owner-loans", except: :destroy do
      resources :payments, controller: "owner_loan_payments", only: %i[ new create destroy ]
    end
    resources :staff_members, path: "staff" do
      resources :staff_payments, path: "payments", only: %i[ new create show destroy ]
      resources :staff_advances, path: "advances", only: %i[ new create destroy ]
      resources :staff_goals, path: "goals", only: %i[ new create destroy ]
    end
  end

  namespace :farms do
    root "home#index"
    resources :farms, only: %i[ index show new create edit update ]
    resources :payrolls do
      resources :roles, only: %i[ new create edit update destroy ]
      resources :members, only: %i[ new create edit update destroy ]
      resource :timesheet, only: %i[ show update ]
      resources :tasks, only: %i[ new create edit update destroy ]
      resources :payments, only: %i[ new create show destroy ]
      resources :expenses, only: %i[ new create edit update destroy ]
    end
    resources :expense_categories, only: %i[ index new create edit update ]
    # Coffee varieties (Fernando, 2026-11-15), for farms and plots.
    resources :coffee_varieties, path: "varieties", only: %i[ index new create edit update ]
  end

  # «Confirmar cierre» of a daily close and the day's fuel close (Fernando, 2026-11-23).
  resources :daily_close_confirmations, only: %i[ create destroy ]
  resources :fuel_day_closes, only: %i[ create destroy ]

  namespace :loans do
    root "home#index"
    resources :loans do
      # The filtered list on paper, with its totals (Fernando, 2026-11-12).
      get :print, on: :collection
      resources :payments, only: %i[ new create show destroy ]
    end
    resources :credit_accounts, only: %i[ index show ] do
      # Printing a private document for the person (PrivateDocumentPrint).
      resources :document_prints, only: %i[ new create show ]
    end
    # The card beside the loan form with the person picked.
    resources :borrowers, only: :show
    # Collection and follow-up screens (Fernando, 2026-11-03).
    resource :coffee_collection, only: :show
    resource :collection_calendar, only: :show
    resource :portfolio, only: :show
    resource :simulation, only: :show
    resource :daily_close, only: :show
    resources :seasons, only: :index
  end

  # One screen for every report: /reports/purchases?period=this_month...
  namespace :reports do
    root "reports#show"
    resources :saved_reports, only: %i[ index new create destroy ]
    get ":id/charts", to: "reports#charts", as: :report_charts
    get ":id", to: "reports#show", as: :report
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Any other address: a Spanish "page not found" (audited), in every
  # environment, instead of Rails' routing error. Last of ours; Rails' own
  # paths (/rails/...) and the routes engines add after these (turbo-rails'
  # /*_historical_location) are left alone.
  match "*path", to: "errors#not_found", via: :all, format: false,
                 constraints: ->(request) { !request.path.start_with?("/rails/") && !request.path.end_with?("_historical_location") }
end
