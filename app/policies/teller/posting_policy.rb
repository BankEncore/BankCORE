module Teller
  class PostingPolicy < ApplicationPolicy
    def create?
      return false unless user.present?

      [
        "transactions.deposit.create",
        "transactions.withdrawal.create",
        "transactions.transfer.create",
        "transactions.vault_transfer.create",
        "transactions.draft.create",
        "transactions.check_cashing.create",
        "transactions.reversal.create"
      ].any? do |permission_key|
        user.has_permission?(permission_key, branch: Current.branch, workstation: Current.workstation)
      end
    end

    def draft_create?
      return false unless user.present?

      user.has_permission?("transactions.draft.create", branch: Current.branch, workstation: Current.workstation)
    end

    def vault_transfer_create?
      return false unless user.present?

      user.has_permission?("transactions.vault_transfer.create", branch: Current.branch, workstation: Current.workstation)
    end

    def check_cashing_create?
      return false unless user.present?

      user.has_permission?("transactions.check_cashing.create", branch: Current.branch, workstation: Current.workstation)
    end
  end
end
