module Teller
  class PostingPolicy < ApplicationPolicy
    def create?
      return false unless user.present?

      [
        "transactions.deposit.create",
        "transactions.withdrawal.create",
        "transactions.transfer.create",
        "transactions.check_cashing.create"
      ].any? do |permission_key|
        user.has_permission?(permission_key, branch: Current.branch, workstation: Current.workstation)
      end
    end

    def check_cashing_create?
      return false unless user.present?

      user.has_permission?("transactions.check_cashing.create", branch: Current.branch, workstation: Current.workstation)
    end
  end
end
