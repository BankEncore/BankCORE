module Teller
  class DashboardPolicy < ApplicationPolicy
    def index?
      user.present? && user.has_permission?(
        "teller.dashboard.view",
        branch: Current.branch,
        workstation: Current.workstation
      )
    end
  end
end
