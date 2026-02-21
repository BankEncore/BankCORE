module Teller
  class PostingBatchPolicy < ApplicationPolicy
    def show?
      return false unless user.present?

      teller_transaction = record.teller_transaction
      branch = teller_transaction.branch
      workstation = teller_transaction.workstation

      [
        "transactions.deposit.create",
        "transactions.withdrawal.create",
        "transactions.transfer.create"
      ].any? do |permission_key|
        user.has_permission?(permission_key, branch: branch, workstation: workstation)
      end
    end
  end
end
