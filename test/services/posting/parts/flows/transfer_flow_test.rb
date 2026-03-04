# frozen_string_literal: true

require "test_helper"

module Posting
  module Parts
    module Flows
      class TransferFlowTest < ActiveSupport::TestCase
        test "produces balanced legs" do
          flow = TransferFlow.new(
            amount_cents: 1_000,
            fee_cents: 25,
            primary_account_reference: "acct:123",
            counterparty_account_reference: "acct:456",
            fee_income_account_reference: "income:transfer_fee"
          )

          legs = flow.build_entries
          debit_total = legs.select { |l| l[:side] == "debit" }.sum { |l| l[:amount_cents] }
          credit_total = legs.select { |l| l[:side] == "credit" }.sum { |l| l[:amount_cents] }
          assert_equal debit_total, credit_total
        end

        test "correct PAD debit, CAC credit, FEE credit" do
          flow = TransferFlow.new(
            amount_cents: 1_000,
            fee_cents: 25,
            primary_account_reference: "acct:123",
            counterparty_account_reference: "acct:456"
          )

          legs = flow.build_entries

          pad_leg = legs.find { |l| l[:account_reference] == "acct:123" }
          assert pad_leg, "Must have PAD debit leg"
          assert_equal "debit", pad_leg[:side]
          assert_equal 1_000, pad_leg[:amount_cents]

          cac_leg = legs.find { |l| l[:account_reference] == "acct:456" }
          assert cac_leg, "Must have CAC credit leg"
          assert_equal "credit", cac_leg[:side]
          assert_equal 975, cac_leg[:amount_cents], "CAC = amount - fee = 1000 - 25"

          fee_leg = legs.find { |l| l[:account_reference] == "income:transfer_fee" }
          assert fee_leg, "Must have FEE credit leg"
          assert_equal "credit", fee_leg[:side]
          assert_equal 25, fee_leg[:amount_cents]
        end

        test "raises when amount_cents <= 0" do
          flow = TransferFlow.new(
            amount_cents: 0,
            fee_cents: 0,
            primary_account_reference: "acct:123",
            counterparty_account_reference: "acct:456"
          )

          assert_raises(PartBuilder::ValidationError) { flow.build_entries }
        end

        test "raises when fee_cents > amount_cents" do
          flow = TransferFlow.new(
            amount_cents: 500,
            fee_cents: 600,
            primary_account_reference: "acct:123",
            counterparty_account_reference: "acct:456"
          )

          error = assert_raises(PartBuilder::ValidationError) { flow.build_entries }
          assert_match /FEE.*exceeds PAD/i, error.message
        end

        test "omits FEE leg when fee_cents is zero" do
          flow = TransferFlow.new(
            amount_cents: 1_000,
            fee_cents: 0,
            primary_account_reference: "acct:123",
            counterparty_account_reference: "acct:456"
          )

          legs = flow.build_entries
          fee_legs = legs.select { |l| l[:account_reference] == "income:transfer_fee" }
          assert_equal 0, fee_legs.size
          assert_equal 2, legs.size, "PAD + CAC only"
        end
      end
    end
  end
end
