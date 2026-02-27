# frozen_string_literal: true

module Csr
  class AdvisoryPolicy < ApplicationPolicy
    def index?
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
          user.has_permission?("csr.dashboard.view", branch: Current.branch, workstation: Current.workstation)
      end

      def advisories_create?
        return false unless user.present?
        user.has_permission?("advisories.create", branch: Current.branch, workstation: Current.workstation)
      end

      def advisories_edit?
        return false unless user.present?
        user.has_permission?("advisories.edit", branch: Current.branch, workstation: Current.workstation)
      end
  end
end
