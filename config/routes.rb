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

  namespace :administration do
    root "home#index"
    resources :people do
      # Merge another person into this one (Fernando, 2026-10-14).
      resource :merge, only: %i[ new create ], controller: "person_merges"
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
    resources :users, only: %i[ index show new create edit update ] do
      member do
        get :reset_password, action: :edit_password
        patch :reset_password
      end
    end
  end

  namespace :trading do
    root "home#index"
    resources :purchases do
      patch :void, on: :member
      # Pay the producer's loans with this purchase ("pago con café").
      resource :loan_settlement, only: %i[ new create ]
    end
    resources :invoices, only: %i[ index show new create ] do
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

  # Comercialización (Fernando, 2026-10-23): trucks leave with coffee for a
  # buyer, are weighed again there, and are sold and collected.
  namespace :sales do
    root "home#index"
    resources :shipments, except: :destroy do
      patch :void, on: :member
      # Weighed on the buyer's scale.
      resource :arrival, only: %i[ edit update ]
    end
    resources :sales, only: %i[ index show new create ] do
      patch :void, on: :member
      # What the buyer pays ("cobros"), each with its receipt.
      resources :payments, only: %i[ new create show destroy ], controller: "sale_payments"
    end
    resources :buyers, except: :destroy do
      # Advances the buyer gives, paid back with coffee.
      resources :buyer_advances, path: "advances", only: %i[ new create show destroy ]
    end
    resources :carriers, except: :destroy
    resources :trucks, except: :destroy
    resource :stock, only: :show
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
    resources :money_accounts, except: :destroy
    resources :account_transfers, only: %i[ new create destroy ]
    resources :other_incomes, only: %i[ new create destroy ]
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
  end

  namespace :loans do
    root "home#index"
    resources :loans do
      resources :payments, only: %i[ new create show destroy ]
    end
    resources :credit_accounts, only: %i[ index show ] do
      # Printing a private document for the person (PrivateDocumentPrint).
      resources :document_prints, only: %i[ new create show ]
    end
    # The card beside the loan form with the person picked.
    resources :borrowers, only: :show
    resources :supplies, only: %i[ index new create edit update ]
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
