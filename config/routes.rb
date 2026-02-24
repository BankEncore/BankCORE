Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  namespace :teller do
    root "dashboard#index"
    resources :parties, only: [ :index, :show, :new, :create, :edit, :update ] do
      collection do
        get :search
      end
      member do
        get :accounts
      end
    end
    resources :accounts, only: [ :index, :show, :new, :create, :edit, :update ]
    resources :deposits, only: [ :new, :create ]
    resources :withdrawals, only: [ :new, :create ]
    resources :transfers, only: [ :new, :create ]
    resources :vault_transfers, only: [ :new, :create ]
    resources :drafts, only: [ :new, :create ]
    resources :check_cashings, only: [ :new, :create ]
    resource :context, only: [ :show, :update ]
    get "transactions/deposit", to: "transaction_pages#deposit", as: :deposit_transaction
    get "transactions/withdrawal", to: "transaction_pages#withdrawal", as: :withdrawal_transaction
    get "transactions/transfer", to: "transaction_pages#transfer", as: :transfer_transaction
    get "transactions/vault_transfer", to: "transaction_pages#vault_transfer", as: :vault_transfer_transaction
    get "transactions/draft", to: "transaction_pages#draft", as: :draft_transaction
    get "transactions/check_cashing", to: "transaction_pages#check_cashing", as: :check_cashing_transaction
    get "transactions/search", to: "transaction_searches#index", as: :transaction_search
    get "account_reference", to: "account_references#show", as: :account_reference
    get "account_history", to: "account_references#history", as: :account_history
    get "workflow_schema", to: "workflow_schemas#show", as: :workflow_schema
    post "transactions/validate", to: "transactions#validate", as: :validate_transaction
    post "approvals", to: "approvals#create", as: :approvals
    post "posting/check", to: "posting_checks#create", as: :posting_check
    post "posting", to: "postings#create", as: :posting
    get "history", to: "transaction_history#index", as: :history
    get "receipts/:request_id", to: "receipts#show", as: :receipt
    resource :teller_session, only: [ :new, :create ] do
      patch :assign_drawer
      patch :close
    end
  end

  namespace :csr do
    root "dashboard#index"
    resources :parties, only: [ :index, :show, :new, :create, :edit, :update ]
    resources :accounts, only: [ :index, :show, :new, :create, :edit, :update ] do
      resources :account_owners, only: [ :create, :destroy, :update ], path: "owners"
    end
    resource :context, only: [ :show, :update ]
  end

  namespace :ops do
    root "dashboard#index"
    get "ledger", to: "ledger#index", as: :ledger
  end

  namespace :admin do
    root "dashboard#index"
    resources :branches do
      resources :workstations, only: [ :new, :create ], shallow: true
      resources :cash_locations, only: [ :new, :create ], shallow: true
    end
    resources :workstations, only: [ :index, :show, :edit, :update, :destroy ]
    resources :cash_locations, only: [ :index, :show, :edit, :update, :destroy ]
    resources :cash_location_assignments, only: [ :index, :show ]
    resources :users do
      resources :user_roles, only: [ :create, :destroy ], path: "roles"
    end
    resources :roles do
      resources :user_roles, only: [ :create, :destroy ], path: "users", controller: "role_users"
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
