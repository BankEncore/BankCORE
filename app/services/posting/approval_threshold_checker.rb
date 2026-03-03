# frozen_string_literal: true

module Posting
  class ApprovalThresholdChecker
    def self.call(posting_params:, entries:, default_cash_account_reference:)
      new(
        posting_params: posting_params,
        entries: entries,
        default_cash_account_reference: default_cash_account_reference
      ).call
    end

    def initialize(posting_params:, entries:, default_cash_account_reference:)
      @posting_params = posting_params.to_h.symbolize_keys
      @entries = Array(entries).map { |e| e.to_h.symbolize_keys }
      @default_cash_account_reference = default_cash_account_reference.to_s
    end

    def call
      trigger_key, transaction_type = resolve_trigger_and_type
      return nil if trigger_key.blank?

      amount_cents = compute_amount(trigger_key, transaction_type)
      return nil if amount_cents <= 0

      threshold = ApprovalThreshold.find_for(trigger_key: trigger_key, transaction_type: transaction_type)
      return nil if threshold.blank?
      return nil if amount_cents < threshold.threshold_cents

      {
        policy_trigger: threshold.policy_trigger,
        threshold_cents: threshold.threshold_cents,
        amount_cents: amount_cents,
        trigger_key: trigger_key
      }
    end

    private
      attr_reader :posting_params, :entries, :default_cash_account_reference

      def resolve_trigger_and_type
        transaction_type = effective_transaction_type
        trigger_key = trigger_key_for(transaction_type)
        [ trigger_key, transaction_type ]
      end

      def effective_transaction_type
        return posting_params[:transaction_type].to_s unless posting_params[:transaction_type].to_s == "reversal"

        posting_params.dig(:metadata, :reversal, :original_transaction_type).to_s.presence || "reversal"
      end

      def trigger_key_for(transaction_type)
        case transaction_type
        when "deposit"
          "cash_in"
        when "withdrawal"
          "cash_out"
        when "draft"
          cash_legs.any? { |leg| leg.fetch(:side) == "debit" } ? "cash_in" : "amount"
        when "check_cashing"
          "cash_out"
        when "misc_receipt"
          cash_legs.any? { |leg| leg.fetch(:side) == "debit" } ? "cash_in" : "amount"
        when "bill_payment"
          cash_legs.any? { |leg| leg.fetch(:side) == "debit" } ? "cash_in" : "amount"
        when "transfer"
          "amount"
        when "vault_transfer"
          "vault_transfer"
        when "reversal"
          trigger_key_for_reversal
        else
          "amount"
        end
      end

      def trigger_key_for_reversal
        original_type = posting_params.dig(:metadata, :reversal, :original_transaction_type).to_s
        case original_type
        when "deposit", "draft", "misc_receipt", "bill_payment"
          "cash_out"
        when "withdrawal", "check_cashing"
          "cash_in"
        when "vault_transfer"
          "vault_transfer"
        else
          "amount"
        end
      end

      def compute_amount(trigger_key, transaction_type)
        case trigger_key
        when "cash_in"
          compute_cash_in
        when "cash_out"
          compute_cash_out
        when "vault_transfer"
          compute_vault_transfer_amount
        when "amount"
          posting_params[:amount_cents].to_i
        else
          0
        end
      end

      def compute_cash_in
        cash_legs.select { |leg| leg.fetch(:side) == "debit" }.sum { |leg| leg.fetch(:amount_cents).to_i }
      end

      def compute_cash_out
        cash_legs.select { |leg| leg.fetch(:side) == "credit" }.sum { |leg| leg.fetch(:amount_cents).to_i }
      end

      def compute_vault_transfer_amount
        return 0 if default_cash_account_reference.blank?

        drawer_legs = entries.select do |leg|
          leg.fetch(:account_reference).to_s == default_cash_account_reference
        end
        drawer_legs.sum { |leg| leg.fetch(:amount_cents).to_i }
      end

      def cash_legs
        entries.select { |leg| leg.fetch(:account_reference).to_s.start_with?("cash:") }
      end
  end
end
