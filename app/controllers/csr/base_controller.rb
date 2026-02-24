# frozen_string_literal: true

module Csr
  class BaseController < ApplicationController
    layout "csr"

    before_action :require_csr_context!

    private
      def require_csr_context!
        return if controller_path == "csr/contexts"
        return if current_branch.present?

        store_csr_return_to
        redirect_to csr_context_path, alert: "Select branch before continuing."
      end

      def store_csr_return_to
        return unless %i[get head].include?(request.request_method_symbol)

        session[:csr_return_to] = request.fullpath
      end

      def consume_csr_return_to(default_path)
        session.delete(:csr_return_to).presence || default_path
      end
  end
end
