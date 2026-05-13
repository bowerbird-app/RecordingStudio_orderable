# frozen_string_literal: true

RecordingStudioOrderable::Engine.routes.draw do
  get "setup", to: "docs#setup", as: :setup
  get "config", to: "docs#configuration", as: :config
  get "methods", to: "docs#methods_page", as: :methods
  get "views", to: "docs#views_page", as: :views
  resources :recording_order_lists, only: %i[new create]
  root "home#index"
end
