# frozen_string_literal: true

module Csr
  class AccountPolicy < ApplicationPolicy
    def index?
      csr_dashboard?
    end

    def show?
      csr_dashboard?
    end

    def create?
      csr_dashboard?
    end

    def new?
      create?
    end

    def update?
      csr_dashboard?
    end

    def destroy?
      false
    end

    private

      def csr_dashboard?
        user.present? && user.has_permission?(
          "csr.dashboard.view",
          branch: Current.branch,
          workstation: nil
        )
      end
  end
end
