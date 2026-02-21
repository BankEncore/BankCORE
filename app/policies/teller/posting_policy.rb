module Teller
  class PostingPolicy < ApplicationPolicy
    def create?
      return false unless user.present?

      [
        "transactions.deposit.create",
        "transactions.withdrawal.create",
        "transactions.transfer.create"
      ].any? do |permission_key|
        user.has_permission?(permission_key, branch: Current.branch, workstation: Current.workstation)
      end
    end
  end
end
