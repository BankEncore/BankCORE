module Teller
  class TransactionsController < BaseController
    include PostingPrerequisites
    include PostingRequestBuilder

    before_action :ensure_authorized
    before_action :require_posting_context!

    def validate
      errors = validation_errors(validation_params)
      entries = normalized_entries(validation_params)
      debit_total = entries.select { |entry| entry[:side] == "debit" }.sum { |entry| entry[:amount_cents].to_i }
      credit_total = entries.select { |entry| entry[:side] == "credit" }.sum { |entry| entry[:amount_cents].to_i }
      imbalance_cents = (debit_total - credit_total).abs

      if imbalance_cents.positive?
        errors << "Posting entries are out of balance"
      end

      approval_trigger = approval_policy_trigger(validation_params)
      approval_needed = approval_trigger.present?
      context = approval_needed ? approval_policy_context(validation_params) : {}

      render json: {
        ok: errors.empty?,
        errors: errors,
        approval_required: approval_needed,
        approval_reason: approval_needed ? approval_reason_for(approval_trigger) : nil,
        approval_policy_trigger: approval_trigger,
        approval_policy_context: context,
        totals: {
          debit_cents: debit_total,
          credit_cents: credit_total,
          imbalance_cents: imbalance_cents,
          amount_cents: validation_params[:amount_cents].to_i
        }
      }
    end

    private
      def ensure_authorized
        authorize([ :teller, :posting ], :create?)
      end

      def validation_params
        params.permit(
          :request_id,
          :transaction_type,
          :amount_cents,
          :currency,
          :primary_account_reference,
          :counterparty_account_reference,
          :cash_account_reference,
          :vault_transfer_direction,
          :vault_transfer_source_cash_account_reference,
          :vault_transfer_destination_cash_account_reference,
          :vault_transfer_reason_code,
          :vault_transfer_memo,
          :fee_cents,
          :fee_income_account_reference,
          :party_id,
          :id_type,
          :id_number,
          :draft_amount_cents,
          :draft_fee_cents,
          :draft_cash_cents,
          :draft_account_cents,
          :draft_payee_name,
          :draft_instrument_number,
          :draft_liability_account_reference,
          :draft_fee_income_account_reference,
          :misc_receipt_type_id,
          :income_account_reference,
          :unit_amount_cents,
          :quantity,
          :memo,
          :misc_cash_cents,
          :misc_account_cents,
          :cash_back_cents,
          :payee_id,
          :payee_reference,
          :payment_cents,
          :liability_account_reference,
          :bill_payment_cash_cents,
          :bill_payment_account_cents,
          check_items: [ :routing, :account, :number, :account_reference, :amount_cents, :check_type, :hold_reason, :hold_until ],
          entries: [ :side, :account_reference, :amount_cents ],
          denomination_lines: [ :cash_denomination_id, :qty, :amount_cents ]
        )
      end

      def validation_errors(posting_params)
        Posting::WorkflowValidator.errors(posting_params)
      end

      def approval_reason_for(policy_trigger)
        case policy_trigger.to_s
        when "cash_in_threshold" then "Cash-in threshold exceeded"
        when "cash_out_threshold" then "Cash-out threshold exceeded"
        when "vault_transfer_threshold" then "Vault transfer threshold exceeded"
        when "amount_threshold" then "Amount threshold exceeded"
        else "Approval required"
        end
      end
  end
end
