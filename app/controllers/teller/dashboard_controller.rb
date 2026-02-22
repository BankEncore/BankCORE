module Teller
  class DashboardController < BaseController
    def index
      authorize([ :teller, :dashboard ], :index?)
      @teller_session = current_teller_session
    end
  end
end
