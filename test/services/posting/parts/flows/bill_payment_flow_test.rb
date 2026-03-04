# frozen_string_literal: true

require "test_helper"

module Posting
  module Parts
    module Flows
      class BillPaymentFlowTest < ActiveSupport::TestCase
        test "produces balanced entries for cash-only" do
          flow = BillPaymentFlow.new(
            payment_cents: 2_000,
            fee_cents: 0,
            bill_payment_cash_cents: 2_000,
            bill_payment_account_cents: 0,
            check_items: [],
            primary_account_reference: "acct:123",
            cash_account_reference: "cash:D01",
            liability_account_reference: "bill_pmt:payee1"
          )

          legs = flow.build_entries
          debit_total = legs.select { |l| l[:side] == "debit" }.sum { |l| l[:amount_cents] }
          credit_total = legs.select { |l| l[:side] == "credit" }.sum { |l| l[:amount_cents] }
          assert_equal debit_total, credit_total
        end

        test "includes fee leg when fee_cents positive" do
          flow = BillPaymentFlow.new(
            payment_cents: 2_000,
            fee_cents: 50,
            bill_payment_cash_cents: 2_050,
            bill_payment_account_cents: 0,
            check_items: [],
            primary_account_reference: "acct:123",
            cash_account_reference: "cash:D01",
            liability_account_reference: "bill_pmt:payee1",
            fee_income_account_reference: "income:bill_payment_fee"
          )

          legs = flow.build_entries
          assert legs.any? { |l| l[:account_reference] == "income:bill_payment_fee" && l[:side] == "credit" && l[:amount_cents] == 50 }
        end

        test "raises when liability_account_reference blank" do
          flow = BillPaymentFlow.new(
            payment_cents: 2_000,
            fee_cents: 0,
            bill_payment_cash_cents: 2_000,
            bill_payment_account_cents: 0,
            check_items: [],
            primary_account_reference: "acct:123",
            cash_account_reference: "cash:D01",
            liability_account_reference: ""
          )

          assert_raises(PartBuilder::ValidationError) { flow.build_entries }
        end
      end
    end
  end
end
