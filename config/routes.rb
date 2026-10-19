Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  # Public: this is where a monitoring tool sends an alert. It is the entry
  # point of the aort dilimi — an alert opens (or is grouped into) an incident.
  get  "alerts/new",                 to: "alerts#new",      as: :new_alert
  post "alerts",                     to: "alerts#create",   as: :alerts
  get  "alerts/received/:reference", to: "alerts#received", as: :alert_received

  # Autonomous agent->agent simulation dashboard (authentication required).
  get  "simulation",       to: "simulation#index", as: :simulation
  post "simulation/run",   to: "simulation#run",   as: :run_simulation
  post "simulation/reset", to: "simulation#reset", as: :reset_simulation

  # Responder workspace (authentication required).
  resources :incidents, only: %i[index show] do
    member do
      patch :acknowledge
      patch :resolve
      patch :reopen
    end
    resources :notes, only: :create
  end

  # Health check for load balancers / Render.
  get "up" => "rails/health#show", as: :rails_health_check

  # Responders land on the incident queue; visitors are sent to login.
  root "incidents#index"
end
