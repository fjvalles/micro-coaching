require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  devise_for :admin_users

  authenticate :admin_user do
    namespace :admin do
      root to: "dashboard#index"

      resources :programs do
        resources :day_contents, only: [ :index, :new, :create ], controller: "day_contents"
      end
      resources :day_contents
      resources :companies do
        member do
          post :discard
          post :undiscard
        end
      end
      resources :participants do
        member do
          post :enroll
          post :discard
          post :undiscard
        end
      end
      resources :prompt_templates, only: [ :index, :show, :edit, :update ] do
        member do
          post :analyze
          post :apply_suggestion
        end
      end
      get  "metodologia",         to: "methodology#index",   as: :methodology
      post "metodologia/refresh", to: "methodology#refresh", as: :refresh_methodology

      resources :conversations, only: [ :index, :show, :destroy ]
      resources :daily_reports, only: [ :index, :show, :destroy ]
      resources :settings, only: [ :index, :edit, :update ]
      resources :admin_users

      resources :pending_responses, only: [ :index, :show, :update ] do
        member do
          post :approve
          post :send_now
          post :reject
        end
      end
      post "response_mode", to: "response_modes#update", as: :update_response_mode

      get "audit_log", to: "audit_logs#index", as: :audit_log
      get "finances",  to: "finances#index",   as: :finances
      resources :payments, only: [ :index, :show ]

      get "docs",           to: "docs#index",     as: :docs
      get "docs/strategy",  to: "docs#strategy",  as: :docs_strategy
      get "docs/technical", to: "docs#technical", as: :docs_technical
      get "docs/:id",       to: "docs#show",      as: :doc, constraints: { id: /[\w\-]+/ }
    end

    mount Sidekiq::Web => "/sidekiq"
  end

  namespace :webhooks do
    get  "whatsapp", to: "whatsapp#verify"
    post "whatsapp", to: "whatsapp#receive"
  end

  get "up" => "rails/health#show", as: :rails_health_check

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest, defaults: { format: :json }
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  post "preview_challenge", to: "home#preview_challenge", as: :preview_challenge
  post "enroll", to: "home#enroll", as: :enroll
  get "privacidad", to: "home#privacidad", as: :privacidad

  # Pagos (Webpay Plus). retorno acepta GET (flujo normal) y POST (abort/timeout).
  get  "pagos",         to: "payments#new",    as: :pagos
  post "pagos",         to: "payments#create"
  match "pagos/retorno", to: "payments#commit", as: :pago_retorno, via: %i[get post]

  # Portal del participante (login passwordless por magic-link).
  namespace :portal do
    get    "acceso",       to: "sessions#new",     as: :login
    post   "acceso",       to: "sessions#create"
    get    "sesion/:token", to: "sessions#show",   as: :session
    delete "salir",        to: "sessions#destroy", as: :logout
    root to: "dashboard#show"
  end

  root to: "home#index"
end
