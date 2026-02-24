# frozen_string_literal: true

module Admin
  class ApplicationPolicy < ::ApplicationPolicy
    def admin?
      user.present? && user.has_permission?("administration.workspace.view")
    end

    def index?
      admin?
    end

    def show?
      admin?
    end

    def create?
      admin?
    end

    def new?
      create?
    end

    def update?
      admin?
    end

    def edit?
      update?
    end

    def destroy?
      admin?
    end

    class Scope
      attr_reader :user, :scope

      def initialize(user, scope)
        @user = user
        @scope = scope
      end

      def resolve
        user.present? && user.has_permission?("administration.workspace.view") ? scope.all : scope.none
      end
    end
  end
end
