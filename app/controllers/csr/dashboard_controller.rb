# frozen_string_literal: true

module Csr
  class DashboardController < BaseController
    def index
      authorize([ :csr, :dashboard ], :index?)
    end
  end
end
