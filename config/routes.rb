Rails.application.routes.draw do
  # NEU: Die Routen für unsere Dashboards
  get "dashboards/admin"
  get "dashboards/trainer"
  get "dashboards/stats"

  resource :mail_setting, only: [:show, :edit, :update] do
    post :test_email
  end

  namespace :admin do
    resource :payment_setting, only: [:show, :edit, :update] do
      post :test_connection
    end
  end

  resources :trainers
  resources :holidays
  resources :participants

  resources :courses do
    member do
      get :generate_trainings
      post :create_generated_trainings
      get :manage # NEU: Der Maschinenraum für einen einzelnen Kurs!
    end
  end

  resources :course_registrations do
    member do
      get :scan
      post :unsubscribe_from_session
    end
  end

  # Stripe payments
  get  '/registrations/:id/checkout', to: 'payments#checkout',  as: 'checkout_registration'
  get  '/payments/success',           to: 'payments#success',   as: 'payments_success'
  get  '/payments/cancel',            to: 'payments#cancel',    as: 'payments_cancel'
  post '/webhooks/stripe',            to: 'stripe_webhooks#create'

  resources :training_sessions do
    member do
      post :toggle_attendance
      get :scanner # NEU: Die Route für den Kamera-Modus
      post :cancel
      post :uncancel
    end
  end

  resources :newsletter_subscribers, only: %i[index create update destroy] do
    collection do
      post :import
      get  :export
    end
    member do
      get :unsubscribe
    end
  end

  resources :newsletters, only: %i[index new create edit update destroy] do
    member do
      post :send_newsletter
      get  :preview
    end
  end

  devise_for :users, controllers: { confirmations: "devise/confirmations" }
  root "courses#index"
end
