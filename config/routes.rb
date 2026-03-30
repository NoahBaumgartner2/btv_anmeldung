Rails.application.routes.draw do
  # NEU: Die Routen für unsere Dashboards
  get 'dashboards/admin'
  get 'dashboards/trainer'

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
      get :scan # NEU: Der geheime Link zum Scannen des Tickets!
    end
  end
  
  resources :training_sessions do
    member do
      post :toggle_attendance
      get :scanner # NEU: Die Route für den Kamera-Modus
    end
  end

  devise_for :users
  root "courses#index"
end