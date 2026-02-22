module Teller
  class BaseController < ApplicationController
    layout "teller"

    before_action :require_teller_context!

    private
      def require_teller_context!
        return if controller_path == "teller/contexts"
        return if teller_context_complete?

        store_teller_return_to
        redirect_to teller_context_path, alert: "Select branch and workstation before continuing."
      end

      def store_teller_return_to
        return unless %i[get head].include?(request.request_method_symbol)

        session[:teller_return_to] = request.fullpath
      end

      def consume_teller_return_to(default_path)
        session.delete(:teller_return_to).presence || default_path
      end
  end
end
