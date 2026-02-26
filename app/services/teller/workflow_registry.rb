module Teller
  class WorkflowRegistry
    WORKFLOWS = {
      "deposit" => {
        label: "Deposit",
        required_fields: [],
        funding_modes: %w[cash check mixed],
        ui_sections: %w[checks],
        entry_profile: "deposit",
        amount_input_mode: "manual",
        effective_amount_source: "cash_plus_checks",
        cash_impact_profile: "inflow",
        primary_account_policy: "always",
        requires_counterparty_account: false,
        cash_account_policy: "always",
        requires_settlement_account: false
      },
      "withdrawal" => {
        label: "Withdrawal",
        required_fields: [],
        funding_modes: %w[cash],
        ui_sections: [],
        entry_profile: "withdrawal",
        amount_input_mode: "manual",
        effective_amount_source: "amount_field",
        cash_impact_profile: "outflow",
        primary_account_policy: "always",
        requires_counterparty_account: false,
        cash_account_policy: "always",
        requires_settlement_account: false
      },
      "transfer" => {
        label: "Transfer",
        required_fields: [],
        funding_modes: %w[account],
        ui_sections: %w[transfer],
        entry_profile: "transfer",
        amount_input_mode: "manual",
        effective_amount_source: "amount_field",
        cash_impact_profile: "none",
        primary_account_policy: "always",
        requires_counterparty_account: true,
        cash_account_policy: "never",
        requires_settlement_account: false
      },
      "check_cashing" => {
        label: "Check Cashing",
        required_fields: %i[party_id],
        funding_modes: %w[check],
        ui_sections: %w[check_cashing checks],
        entry_profile: "check_cashing",
        amount_input_mode: "check_cashing_net_payout",
        effective_amount_source: "check_cashing_net_payout",
        cash_impact_profile: "outflow",
        primary_account_policy: "never",
        requires_counterparty_account: false,
        cash_account_policy: "always",
        requires_settlement_account: false
      },
      "draft" => {
        label: "Bank Draft",
        required_fields: %i[draft_amount_cents draft_payee_name draft_instrument_number draft_liability_account_reference],
        funding_modes: %w[account cash check],
        ui_sections: %w[draft checks],
        entry_profile: "draft",
        amount_input_mode: "draft_amount",
        effective_amount_source: "amount_field",
        cash_impact_profile: "draft_funding",
        primary_account_policy: "draft_account_only",
        requires_counterparty_account: false,
        cash_account_policy: "draft_cash_only",
        requires_settlement_account: false
      },
      "vault_transfer" => {
        label: "Vault Transfer",
        required_fields: %i[vault_transfer_direction vault_transfer_reason_code],
        funding_modes: %w[cash],
        ui_sections: %w[vault_transfer],
        entry_profile: "vault_transfer",
        amount_input_mode: "manual",
        effective_amount_source: "amount_field",
        cash_impact_profile: "vault_directional",
        primary_account_policy: "never",
        requires_counterparty_account: false,
        cash_account_policy: "never",
        requires_settlement_account: false
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
            required_fields: required_fields_for(definition),
            funding_modes: Array(definition[:funding_modes]).map(&:to_s),
            ui_sections: Array(definition[:ui_sections]).map(&:to_s),
            entry_profile: definition.fetch(:entry_profile).to_s,
            amount_input_mode: definition.fetch(:amount_input_mode).to_s,
            effective_amount_source: definition.fetch(:effective_amount_source).to_s,
            cash_impact_profile: definition.fetch(:cash_impact_profile).to_s,
            primary_account_policy: definition.fetch(:primary_account_policy).to_s,
            requires_counterparty_account: definition.fetch(:requires_counterparty_account),
            cash_account_policy: definition.fetch(:cash_account_policy).to_s,
            requires_settlement_account: definition.fetch(:requires_settlement_account)
          }
        end
      end

      private
        def required_fields_for(definition)
          fields = Array(definition[:required_fields]).map(&:to_s)

          if definition.fetch(:primary_account_policy).to_s == "always"
            fields << "primary_account_reference"
          end

          if definition.fetch(:requires_counterparty_account)
            fields << "counterparty_account_reference"
          end

          if definition.fetch(:requires_settlement_account)
            fields << "settlement_account_reference"
          end

          fields.uniq
        end
    end
  end
end
