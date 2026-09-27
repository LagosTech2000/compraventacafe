Rails.application.routes.draw do
  resource :session, only: %i[ new create destroy ]
  # Password recovery by email is disconnected until there is an email
  # service. Admins reset passwords from the panel instead.
  # resources :passwords, param: :token

  root "dashboard#show"

  namespace :administration do
    root "home#index"
    resources :people
    resources :users, only: %i[ index show new create edit update ] do
      member do
        get :reset_password, action: :edit_password
        patch :reset_password
      end
    end
  end

  namespace :trading do
    root "home#index"
    resources :purchases
    resources :invoices, only: %i[ index show new create update ]
    resources :producers, except: :destroy
    resources :zones, only: %i[ index new create edit update ]
    resource :daily_close, only: :show
  end

  namespace :farms do
    root "home#index"
  end

  namespace :loans do
    root "home#index"
  end

  namespace :reports do
    root "home#index"
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
