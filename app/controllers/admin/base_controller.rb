# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    layout "admin"
    before_action :require_admin_access!

    private
      def require_admin_access!
        return if current_user&.has_permission?("administration.workspace.view")
        redirect_to root_path, alert: "You are not authorized to access the Administration workspace."
      end
  end
end
