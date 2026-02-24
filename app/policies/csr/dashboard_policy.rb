# frozen_string_literal: true

module Csr
  class DashboardPolicy < ApplicationPolicy
    def index?
      user.present? && user.has_permission?(
        "csr.dashboard.view",
        branch: Current.branch,
        workstation: nil
      )
    end
  end
end
