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
          get :versions
          post :enroll
          post :discard
          post :undiscard
          post :send_message
          post :re_enroll
          post :start_program
          post :start_intake
          post :approve_program
        end
        collection do
          post :broadcast
        end
      end
      resources :prompt_templates, only: [ :index, :show, :edit, :update ] do
        member do
          post :analyze
          post :apply_suggestion
        end
      end
      resources :prompt_tuning, only: [ :index, :show ] do
        member do
          post :approve
          patch :update_and_approve
          post :reject
          post :rollback
        end
      end
      get  "metodologia",         to: "methodology#index",   as: :methodology
      post "metodologia/refresh", to: "methodology#refresh", as: :refresh_methodology

      resources :conversations, only: [ :index, :show, :destroy ] do
        member do
          post :retry
        end
      end
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

      # Ops copilot (superadmin-only; gated by copilot_enabled)
      get  "copilot",                       to: "copilot#index",          as: :copilot
      post "copilot/sessions",              to: "copilot#create",         as: :copilot_sessions
      get  "copilot/sessions/:id",          to: "copilot#show",           as: :copilot_session
      post "copilot/sessions/:id/message",  to: "copilot#message",        as: :copilot_session_message
      post "copilot/actions/:id/approve",   to: "copilot#approve_action", as: :copilot_approve_action
      post "copilot/actions/:id/reject",    to: "copilot#reject_action",  as: :copilot_reject_action

      get "health",    to: "health#show",        as: :health
      get "audit_log", to: "audit_logs#index", as: :audit_log
      get "finances",  to: "finances#index",   as: :finances
      get "resultado", to: "profit_loss#index", as: :profit_loss
      resources :payments, only: [ :index, :show ]
      resources :subscriptions, only: [ :index ]
      resources :skills, only: [ :index, :show ]
      resources :resources do
        member do
          patch :approve
          patch :reject
          patch :verify_again
        end
      end
      resources :coach_sessions

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

  # Suscripciones (Webpay Oneclick — cobro recurrente). retorno acepta GET y POST.
  get   "suscripcion",         to: "subscriptions#new",    as: :suscripcion
  post  "suscripcion",         to: "subscriptions#create"
  match "suscripcion/retorno", to: "subscriptions#commit", as: :suscripcion_retorno, via: %i[get post]

  # Portal del participante (login passwordless por magic-link).
  namespace :portal do
    get    "acceso",       to: "sessions#new",     as: :login
    post   "acceso",       to: "sessions#create"
    get    "sesion/:token", to: "sessions#show",   as: :session
    delete "salir",        to: "sessions#destroy", as: :logout

    resource  :program,  only: :show
    resources :resources, only: :index
    resource  :billing,  only: :show
    resource  :profile,  only: %i[show update]
    root to: "dashboard#show"
  end

  root to: "home#index"
end
