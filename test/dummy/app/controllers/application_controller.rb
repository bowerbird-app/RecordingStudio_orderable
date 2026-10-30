class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern unless Rails.env.test?

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  recording_studio_layout do
    devise_controller? ? "application" : nil
  end

  before_action :authenticate_user!
  before_action :set_current_actor

  rescue_from RecordingStudioOrderable::NotAuthorized, with: :recording_studio_orderable_forbidden

  helper_method :demo_nav_links

  private

  def set_current_actor
    Current.actor = current_user
  end

  def recording_studio_orderable_forbidden(_error)
    head :forbidden
  end

  def demo_nav_links
    [
      { text: "Home", href: main_app.root_path },
      { text: "Events", href: main_app.events_path }
    ]
  end
end
