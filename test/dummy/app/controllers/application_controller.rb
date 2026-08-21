class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern unless Rails.env.test?

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  include RecordingStudio::UsesDefaultLayout
  layout :application_layout

  before_action :authenticate_user!
  before_action :set_current_actor

  helper_method :demo_nav_links

  private

  def application_layout
    devise_controller? ? "application" : "recording_studio/default_layout"
  end

  def set_current_actor
    Current.actor = current_user
  end

  def demo_nav_links
    [
      { text: "Home", url: main_app.root_path },
      { text: "Events", url: main_app.events_path }
    ]
  end
end
