# frozen_string_literal: true

RecordingStudioOrderable::Engine.routes.draw do
  resources :recording_order_lists, only: %i[new create]
  root "home#index"
end
