# frozen_string_literal: true

require "test_helper"

module Posting
  module Parts
    module Flows
      class DepositFlowTest < ActiveSupport::TestCase
        test "produces balanced legs for cash-only deposit" do
          flow = DepositFlow.new(
            amount_cents: 5_000,
            cash_back_cents: 0,
            fee_cents: 0,
            check_items: [],
            primary_account_reference: "acct:123",
            cash_account_reference: "cash:D01"
          )

          legs = flow.build_entries
          debit_total = legs.select { |l| l[:side] == "debit" }.sum { |l| l[:amount_cents] }
          credit_total = legs.select { |l| l[:side] == "credit" }.sum { |l| l[:amount_cents] }
          assert_equal debit_total, credit_total
        end

        test "correct CI debit, PAC credit for simple deposit" do
          flow = DepositFlow.new(
            amount_cents: 5_000,
            cash_back_cents: 0,
            fee_cents: 0,
            check_items: [],
            primary_account_reference: "acct:123",
            cash_account_reference: "cash:D01"
          )

          legs = flow.build_entries

          ci_leg = legs.find { |l| l[:account_reference] == "cash:D01" && l[:side] == "debit" }
          assert ci_leg, "Must have CI (cash) debit"
          assert_equal 5_000, ci_leg[:amount_cents]

          pac_leg = legs.find { |l| l[:account_reference] == "acct:123" }
          assert pac_leg, "Must have PAC credit"
          assert_equal "credit", pac_leg[:side]
          assert_equal 5_000, pac_leg[:amount_cents]
        end

        test "CI + CK - CO - FEE = PAC with checks and cash back" do
          flow = DepositFlow.new(
            amount_cents: 3_000,
            cash_back_cents: 500,
            fee_cents: 100,
            check_items: [ { routing: "021", account: "456", number: "1", account_reference: "check:021:456:1", amount_cents: 5_000 } ],
            primary_account_reference: "acct:123",
            cash_account_reference: "cash:D01"
          )

          legs = flow.build_entries
          pac_leg = legs.find { |l| l[:account_reference] == "acct:123" }
          assert_equal 7_400, pac_leg[:amount_cents], "3000 + 5000 - 500 - 100 = 7400"

          co_leg = legs.find { |l| l[:account_reference] == "cash:D01" && l[:side] == "credit" }
          assert co_leg
          assert_equal 500, co_leg[:amount_cents]
        end

        test "raises when no cash or checks received" do
          flow = DepositFlow.new(
            amount_cents: 0,
            cash_back_cents: 0,
            fee_cents: 0,
            check_items: [],
            primary_account_reference: "acct:123",
            cash_account_reference: "cash:D01"
          )

          assert_raises(PartBuilder::ValidationError) { flow.build_entries }
        end

        test "raises when cash back exceeds received" do
          flow = DepositFlow.new(
            amount_cents: 1_000,
            cash_back_cents: 2_000,
            fee_cents: 0,
            check_items: [],
            primary_account_reference: "acct:123",
            cash_account_reference: "cash:D01"
          )

          error = assert_raises(PartBuilder::ValidationError) { flow.build_entries }
          assert_match /cash_back|cannot exceed/i, error.message
        end
      end
    end
  end
end
