# frozen_string_literal: true

require "test_helper"

module Posting
  module Parts
    module Flows
      class WithdrawalFlowTest < ActiveSupport::TestCase
        test "produces balanced legs" do
          flow = WithdrawalFlow.new(
            amount_cents: 5_000,
            fee_cents: 100,
            primary_account_reference: "acct:123",
            cash_account_reference: "cash:D01",
            fee_income_account_reference: "income:withdrawal_fee"
          )

          legs = flow.build_entries
          debit_total = legs.select { |l| l[:side] == "debit" }.sum { |l| l[:amount_cents] }
          credit_total = legs.select { |l| l[:side] == "credit" }.sum { |l| l[:amount_cents] }
          assert_equal debit_total, credit_total
        end

        test "correct PAD debit, CO credit, FEE credit" do
          flow = WithdrawalFlow.new(
            amount_cents: 5_000,
            fee_cents: 100,
            primary_account_reference: "acct:123",
            cash_account_reference: "cash:D01"
          )

          legs = flow.build_entries

          pad_leg = legs.find { |l| l[:account_reference] == "acct:123" }
          assert pad_leg, "Must have PAD debit leg"
          assert_equal "debit", pad_leg[:side]
          assert_equal 5_000, pad_leg[:amount_cents]

          co_leg = legs.find { |l| l[:account_reference] == "cash:D01" }
          assert co_leg, "Must have CO credit leg"
          assert_equal "credit", co_leg[:side]
          assert_equal 4_900, co_leg[:amount_cents], "CO = amount - fee = 5000 - 100"

          fee_leg = legs.find { |l| l[:account_reference] == "income:withdrawal_fee" }
          assert fee_leg, "Must have FEE credit leg"
          assert_equal "credit", fee_leg[:side]
          assert_equal 100, fee_leg[:amount_cents]
        end

        test "raises when amount_cents <= 0" do
          flow = WithdrawalFlow.new(
            amount_cents: 0,
            fee_cents: 0,
            primary_account_reference: "acct:123",
            cash_account_reference: "cash:D01"
          )

          assert_raises(PartBuilder::ValidationError) { flow.build_entries }
        end

        test "raises when fee_cents > amount_cents" do
          flow = WithdrawalFlow.new(
            amount_cents: 1_000,
            fee_cents: 1_500,
            primary_account_reference: "acct:123",
            cash_account_reference: "cash:D01"
          )

          error = assert_raises(PartBuilder::ValidationError) { flow.build_entries }
          assert_match /FEE.*exceeds PAD/i, error.message
        end

        test "omits FEE leg when fee_cents is zero" do
          flow = WithdrawalFlow.new(
            amount_cents: 5_000,
            fee_cents: 0,
            primary_account_reference: "acct:123",
            cash_account_reference: "cash:D01"
          )

          legs = flow.build_entries
          fee_legs = legs.select { |l| l[:account_reference] == "income:withdrawal_fee" }
          assert_equal 0, fee_legs.size
          assert_equal 2, legs.size, "PAD + CO only"
        end
      end
    end
  end
end
