# frozen_string_literal: true

module Teller
  class AccountPolicy < ApplicationPolicy
    def index?
      teller_dashboard?
    end

    def show?
      teller_dashboard?
    end

    def create?
      teller_dashboard?
    end

    def new?
      create?
    end

    def update?
      teller_dashboard?
    end

    def edit?
      update?
    end

    def related_parties?
      show?
    end

    def destroy?
      false
    end

    private

      def teller_dashboard?
        user.present? && user.has_permission?(
          "teller.dashboard.view",
          branch: Current.branch,
          workstation: Current.workstation
        )
      end
  end
end
