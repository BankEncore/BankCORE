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

      render json: {
        ok: errors.empty?,
        errors: errors,
        approval_required: approval_needed,
        approval_reason: approval_needed ? "Amount threshold exceeded" : nil,
        approval_policy_trigger: approval_trigger,
        approval_policy_context: approval_needed ? approval_policy_context(validation_params) : {},
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
          :draft_funding_source,
          :draft_amount_cents,
          :draft_fee_cents,
          :draft_payee_name,
          :draft_instrument_number,
          :draft_liability_account_reference,
          :draft_fee_income_account_reference,
          entries: [ :side, :account_reference, :amount_cents ]
        )
      end

      def validation_errors(posting_params)
        errors = []
        errors << "Transaction type is required" if posting_params[:transaction_type].blank?
        errors << "Amount must be greater than zero" unless posting_params[:amount_cents].to_i.positive?

        case posting_params[:transaction_type].to_s
        when "deposit", "withdrawal"
          errors << "Primary account reference is required" if posting_params[:primary_account_reference].blank?
        when "transfer"
          if Array(posting_params[:entries]).blank?
            errors << "From account reference is required" if posting_params[:primary_account_reference].blank?
            errors << "To account reference is required" if posting_params[:counterparty_account_reference].blank?
          end
        when "check_cashing"
          if Array(posting_params[:entries]).blank?
            errors << "Primary account reference is required" if posting_params[:primary_account_reference].blank?
          end
        when "draft"
          funding_source = posting_params[:draft_funding_source].to_s
          errors << "Draft amount must be greater than zero" unless posting_params[:draft_amount_cents].to_i.positive?
          errors << "Payee name is required" if posting_params[:draft_payee_name].blank?
          errors << "Instrument number is required" if posting_params[:draft_instrument_number].blank?
          errors << "Liability account reference is required" if posting_params[:draft_liability_account_reference].blank?

          if funding_source == "cash"
            errors << "Cash account reference is required" if posting_params[:cash_account_reference].blank?
          else
            errors << "Primary account reference is required" if posting_params[:primary_account_reference].blank?
          end
        end

        errors
      end
  end
end
