# frozen_string_literal: true

RecordingStudioOrderable::Engine.routes.draw do
  resources :recording_studio_orders, only: %i[index show new create edit]
  root "home#index"
end
