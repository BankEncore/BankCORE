module Teller
  class WorkflowRegistry
    WORKFLOWS = {
      "deposit" => {
        label: "Deposit",
        required_fields: %i[primary_account_reference],
        funding_modes: %w[cash check mixed],
        ui_sections: %w[checks],
        entry_profile: "deposit"
      },
      "withdrawal" => {
        label: "Withdrawal",
        required_fields: %i[primary_account_reference],
        funding_modes: %w[cash],
        ui_sections: [],
        entry_profile: "withdrawal"
      },
      "transfer" => {
        label: "Transfer",
        required_fields: %i[primary_account_reference counterparty_account_reference],
        funding_modes: %w[account],
        ui_sections: [],
        entry_profile: "transfer"
      },
      "check_cashing" => {
        label: "Check Cashing",
        required_fields: %i[check_amount_cents settlement_account_reference],
        funding_modes: %w[check],
        ui_sections: %w[check_cashing],
        entry_profile: "check_cashing"
      },
      "draft" => {
        label: "Bank Draft",
        required_fields: %i[draft_amount_cents draft_payee_name draft_instrument_number draft_liability_account_reference],
        funding_modes: %w[account cash],
        ui_sections: %w[draft],
        entry_profile: "draft"
      },
      "vault_transfer" => {
        label: "Vault Transfer",
        required_fields: %i[vault_transfer_direction vault_transfer_reason_code],
        funding_modes: %w[cash],
        ui_sections: %w[vault_transfer],
        entry_profile: "vault_transfer"
      }
    }.freeze

    class << self
      def fetch(transaction_type)
        WORKFLOWS[transaction_type.to_s]
      end

      def supported_transaction_type?(transaction_type)
        WORKFLOWS.key?(transaction_type.to_s)
      end

      def workflow_schema
        WORKFLOWS.transform_values do |definition|
          {
            label: definition.fetch(:label),
            required_fields: Array(definition[:required_fields]).map(&:to_s),
            funding_modes: Array(definition[:funding_modes]).map(&:to_s),
            ui_sections: Array(definition[:ui_sections]).map(&:to_s),
            entry_profile: definition.fetch(:entry_profile).to_s
          }
        end
      end
    end
  end
end
