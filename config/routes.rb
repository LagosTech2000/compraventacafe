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
    resources :zones, only: %i[ index new create edit update ]
    resource :daily_close, only: :show
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
    resources :credit_accounts, only: %i[ index show ]
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
