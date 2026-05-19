# frozen_string_literal: true

RecordingStudioOrderable::Engine.routes.draw do
  resources :recording_studio_orders, only: %i[new create]
  root "home#index"
end
