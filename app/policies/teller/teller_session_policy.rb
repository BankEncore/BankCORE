module Teller
  class TellerSessionPolicy < ApplicationPolicy
    def new?
      open?
    end

    def create?
      open?
    end

    def close?
      user.present? && user.has_permission?(
        "sessions.close",
        branch: Current.branch,
        workstation: Current.workstation
      )
    end

    private
      def open?
        user.present? && user.has_permission?(
          "sessions.open",
          branch: Current.branch,
          workstation: Current.workstation
        )
      end
  end
end
