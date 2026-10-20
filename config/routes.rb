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
  post "simulation/run",    to: "simulation#run",    as: :run_simulation
  post "simulation/tick",   to: "simulation#tick",   as: :tick_simulation
  post "simulation/submit", to: "simulation#submit", as: :submit_simulation
  post "simulation/scan_store", to: "simulation#scan_store", as: :scan_store_simulation
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

  # Fake company store (Nimbus) — a real, browsable site that genuinely faults.
  get  "magaza",           to: "store#index",    as: :store
  get  "magaza/urun/:id",  to: "store#product",  as: :store_product
  post "magaza/odeme",     to: "store#checkout",  as: :store_checkout
  get  "magaza/panel",     to: "store#panel",     as: :store_panel
  post "magaza/panel/ariza",  to: "store#inject",  as: :store_inject
  post "magaza/panel/duzelt", to: "store#clear",   as: :store_clear
  post "magaza/panel/trafik", to: "store#traffic", as: :store_traffic

  # Public JSON ingest for external systems (the live Nimbus store) to report
  # incidents by routing_key.
  post "api/alerts", to: "api/alerts#create"
  post "api/telemetry", to: "api/telemetry#create"

  # Health check for load balancers / Render.
  get "up" => "rails/health#show", as: :rails_health_check

  # Responders land on the incident queue; visitors are sent to login.
  root "incidents#index"
end
