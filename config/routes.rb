Rails.application.routes.draw do
  resources :holidays
  resources :training_sessions
  resources :trainers
  resources :participants
  resources :courses
  
  devise_for :users
  
  # Reveal health status on /up
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # Die neue Startseite zeigt direkt alle Kurse!
  root "courses#index"
end