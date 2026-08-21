Rails.application.routes.draw do
  devise_for :users

  mount RecordingStudio::Engine, at: "/recording_studio"
  mount RecordingStudioOrderable::Engine, at: "/recording_studio_orderable"

  get "up" => "rails/health#show", as: :rails_health_check
  get "events", to: "events#show", as: :events
  patch "pages/:id/move", to: "home#move", as: :move_page

  root "home#index"
end
