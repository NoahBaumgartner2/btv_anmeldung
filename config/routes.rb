Rails.application.routes.draw do
  post "locale", to: "locales#update", as: :locale

  # NEU: Die Routen für unsere Dashboards
  get "up" => "rails/health#show", as: :rails_health_check
  get  "dashboards/admin"
  get  "dashboards/trainer"
  get  "dashboards/stats"
  get  "dashboards/export_participants", as: "export_participants_dashboard"


  resource :mail_setting, only: [ :show, :edit, :update ] do
    post :test_email
  end

  namespace :admin do
    resource :payment_setting, only: [ :show, :edit, :update ] do
      post :test_connection
      post :sync_payments
    end
    resource :infomaniak_setting, only: [ :show, :edit, :update ] do
      post :test_connection
    end
    resource :club_setting, only: [ :show, :edit, :update ] do
      delete :destroy_logo, on: :member
    end
    resources :export_profiles, only: %i[index new create edit update destroy] do
      member { get :download }
    end
    resource :nds, only: [ :show ], controller: "nds" do
      post :export_persons
      post :import_persons
      post :export_awk
      get  :check_attendance
    end
  end

  resources :trainers
  resources :holidays
  resources :participants

  resources :courses do
    member do
      get  :generate_trainings
      post :create_generated_trainings
      get  :manage
      post :confirm_destroy
    end
  end

  resources :course_registrations do
    member do
      post :scan
      post :unsubscribe_from_session
      post :mark_as_paid
      post :cancel
      post :trainer_cancel
    end
  end

  # SumUp payments
  get  "/registrations/:id/checkout_preview", to: "payments#checkout_preview", as: "checkout_preview_registration"
  get  "/registrations/:id/checkout",         to: "payments#checkout",         as: "checkout_registration"
  get  "/payments/success",                   to: "payments#success",          as: "payments_success"
  get  "/payments/cancel",                    to: "payments#cancel",           as: "payments_cancel"
  post "/webhooks/sumup",                     to: "sumup_webhooks#create"

  resources :training_sessions do
    member do
      post :toggle_attendance
      get :scanner # NEU: Die Route für den Kamera-Modus
      post :cancel
      post :uncancel
    end
  end

  get "newsletter_subscribers/unsubscribe", to: "newsletter_subscribers#unsubscribe", as: "unsubscribe_newsletter_subscriber"

  resources :newsletter_subscribers, only: %i[index create update destroy] do
    collection do
      post :import
      get  :export
    end
  end

  resources :newsletters, only: %i[index new create edit update destroy] do
    member do
      post :send_newsletter
      get  :preview
    end
  end

  resource :account, only: [ :show, :destroy ] do
    get  :export,                on: :member
    post :subscribe_newsletter,  on: :member
    post :unsubscribe_newsletter, on: :member
  end

  # Dynamische CSS-Variablen (Vereinsfarben) – öffentlich, versioniert via ?v=
  get "/club_colors.css", to: "club_colors#show", as: :club_colors

  devise_for :users, controllers: {
    confirmations: "users/confirmations",
    registrations: "users/registrations"
  }
  root "pages#home"
end
