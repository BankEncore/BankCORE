class ApplicationController < ActionController::Base
  include Authentication
  include RequestContext
  include Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
    def current_user
      Current.user
    end

    def user_not_authorized
      redirect_to root_path, alert: "You are not authorized to perform this action."
    end
end
