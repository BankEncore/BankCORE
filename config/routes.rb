Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  namespace :teller do
    root "dashboard#index"
    resources :deposits, only: [ :new, :create ]
    resources :withdrawals, only: [ :new, :create ]
    resources :transfers, only: [ :new, :create ]
    resource :context, only: [ :show, :update ]
    get "transactions/deposit", to: "transaction_pages#deposit", as: :deposit_transaction
    get "transactions/withdrawal", to: "transaction_pages#withdrawal", as: :withdrawal_transaction
    get "transactions/transfer", to: "transaction_pages#transfer", as: :transfer_transaction
    get "account_reference", to: "account_references#show", as: :account_reference
    get "account_history", to: "account_references#history", as: :account_history
    post "transactions/validate", to: "transactions#validate", as: :validate_transaction
    post "approvals", to: "approvals#create", as: :approvals
    post "posting/check", to: "posting_checks#create", as: :posting_check
    post "posting", to: "postings#create", as: :posting
    get "receipts/:request_id", to: "receipts#show", as: :receipt
    resource :teller_session, only: [ :new, :create ] do
      patch :assign_drawer
      patch :close
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
