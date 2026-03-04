# frozen_string_literal: true

require "test_helper"

module Posting
  module Parts
    module Flows
      class MiscReceiptFlowTest < ActiveSupport::TestCase
        test "produces balanced entries for cash-only" do
          flow = MiscReceiptFlow.new(
            amount_cents: 5_000,
            misc_cash_cents: 5_000,
            misc_account_cents: 0,
            check_items: [],
            primary_account_reference: "acct:123",
            cash_account_reference: "cash:D01",
            income_account_reference: "income:misc_receipt"
          )

          legs = flow.build_entries
          debit_total = legs.select { |l| l[:side] == "debit" }.sum { |l| l[:amount_cents] }
          credit_total = legs.select { |l| l[:side] == "credit" }.sum { |l| l[:amount_cents] }
          assert_equal debit_total, credit_total
        end

        test "raises when total payment does not equal amount" do
          flow = MiscReceiptFlow.new(
            amount_cents: 5_000,
            misc_cash_cents: 3_000,
            misc_account_cents: 0,
            check_items: [],
            primary_account_reference: "acct:123",
            cash_account_reference: "cash:D01",
            income_account_reference: "income:misc_receipt"
          )

          assert_raises(PartBuilder::ValidationError) { flow.build_entries }
        end

        test "raises when income_account_reference blank" do
          flow = MiscReceiptFlow.new(
            amount_cents: 5_000,
            misc_cash_cents: 5_000,
            misc_account_cents: 0,
            check_items: [],
            primary_account_reference: "acct:123",
            cash_account_reference: "cash:D01",
            income_account_reference: ""
          )

          assert_raises(PartBuilder::ValidationError) { flow.build_entries }
        end

        test "supports mixed funding with cash and account" do
          flow = MiscReceiptFlow.new(
            amount_cents: 5_000,
            misc_cash_cents: 3_000,
            misc_account_cents: 2_000,
            check_items: [],
            primary_account_reference: "acct:123",
            cash_account_reference: "cash:D01",
            income_account_reference: "income:misc_receipt"
          )

          legs = flow.build_entries
          assert_equal 3, legs.size
          assert legs.any? { |l| l[:account_reference] == "cash:D01" && l[:side] == "debit" && l[:amount_cents] == 3_000 }
          assert legs.any? { |l| l[:account_reference] == "acct:123" && l[:side] == "debit" && l[:amount_cents] == 2_000 }
          assert legs.any? { |l| l[:account_reference] == "income:misc_receipt" && l[:side] == "credit" && l[:amount_cents] == 5_000 }
        end
      end
    end
  end
end
