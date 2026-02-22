module Teller
  class WorkflowRegistry
    WORKFLOWS = {
      "deposit" => {
        label: "Deposit",
        required_fields: %i[primary_account_reference],
        funding_modes: %w[cash check mixed]
      },
      "withdrawal" => {
        label: "Withdrawal",
        required_fields: %i[primary_account_reference],
        funding_modes: %w[cash]
      },
      "transfer" => {
        label: "Transfer",
        required_fields: %i[primary_account_reference counterparty_account_reference],
        funding_modes: %w[account]
      },
      "check_cashing" => {
        label: "Check Cashing",
        required_fields: %i[check_amount_cents settlement_account_reference],
        funding_modes: %w[check]
      },
      "draft" => {
        label: "Bank Draft",
        required_fields: %i[draft_amount_cents draft_payee_name draft_instrument_number draft_liability_account_reference],
        funding_modes: %w[account cash]
      },
      "vault_transfer" => {
        label: "Vault Transfer",
        required_fields: %i[vault_transfer_direction vault_transfer_reason_code],
        funding_modes: %w[cash]
      }
    }.freeze

    class << self
      def fetch(transaction_type)
        WORKFLOWS[transaction_type.to_s]
      end

      def supported_transaction_type?(transaction_type)
        WORKFLOWS.key?(transaction_type.to_s)
      end
    end
  end
end