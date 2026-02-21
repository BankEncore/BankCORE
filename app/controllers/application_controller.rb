class ApplicationController < ActionController::Base
  include Authentication
  include RequestContext
  include Pundit::Authorization

  before_action :require_teller_context!, if: :teller_route?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
    def teller_route?
      controller_path.start_with?("teller/")
    end

    def require_teller_context!
      return if controller_path == "teller/contexts"
      return if teller_context_complete?

      session[:teller_context_return_to] = request.fullpath if %i[get head].include?(request.request_method_symbol)
      redirect_to teller_context_path, alert: "Select branch and workstation before continuing."
    end

    def current_user
      Current.user
    end

    def user_not_authorized
      redirect_to root_path, alert: "You are not authorized to perform this action."
    end
end
