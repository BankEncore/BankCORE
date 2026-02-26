# frozen_string_literal: true

module Teller
  class AdvisoryPolicy < ApplicationPolicy
    def index?
      advisories_view?
    end

    def for_entity?
      advisories_view?
    end

    def acknowledge?
      advisories_view?
    end

    def show?
      advisories_view?
    end

    def create?
      advisories_create?
    end

    def new?
      create?
    end

    def update?
      advisories_edit?
    end

    def edit?
      update?
    end

    def destroy?
      false
    end

    private

      def advisories_view?
        return false unless user.present?
        user.has_permission?("advisories.view", branch: Current.branch, workstation: Current.workstation) ||
          user.has_permission?("teller.dashboard.view", branch: Current.branch, workstation: Current.workstation)
      end

      def advisories_create?
        return false unless user.present?
        user.has_permission?("advisories.create", branch: Current.branch, workstation: Current.workstation) ||
          posting_access?
      end

      def advisories_edit?
        return false unless user.present?
        user.has_permission?("advisories.edit", branch: Current.branch, workstation: Current.workstation) ||
          posting_access?
      end

      def posting_access?
        %w[
          transactions.deposit.create transactions.withdrawal.create
          transactions.transfer.create transactions.vault_transfer.create
          transactions.draft.create transactions.check_cashing.create
          transactions.reversal.create
        ].any? { |k| user.has_permission?(k, branch: Current.branch, workstation: Current.workstation) }
      end
  end
end
