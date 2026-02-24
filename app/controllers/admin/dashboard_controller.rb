# frozen_string_literal: true

module Admin
  class DashboardController < BaseController
    def index
      authorize([ :admin, :dashboard ], :index?)
    end
  end
end
