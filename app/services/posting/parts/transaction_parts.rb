# frozen_string_literal: true

module Posting
  module Parts
    # Value object holding part amounts and references for a transaction.
    # For check cashing: CK (checks in), CO (cash out), FEE (fee withheld).
    # Equation: CK = CO + FEE; Disbursement (CO) = CK - FEE
    class TransactionParts
      attr_reader :check_items, :fee_cents, :cash_account_reference, :fee_income_account_reference

      def initialize(check_items:, fee_cents:, cash_account_reference:, fee_income_account_reference:)
        @check_items = normalize_check_items(check_items)
        @fee_cents = fee_cents.to_i
        @cash_account_reference = cash_account_reference.to_s.strip
        @fee_income_account_reference = fee_income_account_reference.to_s.strip.presence || "income:check_cashing_fee"
      end

      def ck_total
        check_items.sum { |item| item[:amount_cents].to_i }
      end

      def fee_total
        fee_cents
      end

      def co_total
        ck_total - fee_total
      end

      private

      def normalize_check_items(items)
        Array(items).map { |i| i.to_h.symbolize_keys }.select { |i| i[:amount_cents].to_i.positive? }
      end
    end
  end
end
