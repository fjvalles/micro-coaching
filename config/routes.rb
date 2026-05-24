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
      resources :participants do
        member do
          post :enroll
          post :discard
          post :undiscard
        end
      end
      resources :conversations, only: [ :index, :show, :destroy ]
      resources :daily_reports, only: [ :index, :show, :destroy ]
      resources :settings, only: [ :index, :edit, :update ]
      resources :admin_users

      get "docs",          to: "docs#index", as: :docs
      get "docs/:id",      to: "docs#show",  as: :doc, constraints: { id: /[\w\-]+/ }
    end

    mount Sidekiq::Web => "/sidekiq"
  end

  namespace :webhooks do
    get  "whatsapp", to: "whatsapp#verify"
    post "whatsapp", to: "whatsapp#receive"
  end

  get "up" => "rails/health#show", as: :rails_health_check

  post "preview_challenge", to: "home#preview_challenge", as: :preview_challenge
  post "enroll", to: "home#enroll", as: :enroll
  root to: "home#index"
end
