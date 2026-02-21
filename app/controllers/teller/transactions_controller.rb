module Teller
  class TransactionsController < ApplicationController
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

      render json: {
        ok: errors.empty?,
        errors: errors,
        approval_required: approval_required?(validation_params),
        approval_reason: approval_required?(validation_params) ? "Amount threshold exceeded" : nil,
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
        end

        errors
      end
  end
end
