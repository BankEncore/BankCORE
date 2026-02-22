module Teller
  class DashboardController < BaseController
    def index
      authorize([ :teller, :dashboard ], :index?)
      @teller_session = current_teller_session
      @cash_locations = current_branch.cash_locations.active.where(location_type: "vault").order(:name)
    end
  end
end
