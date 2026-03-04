# frozen_string_literal: true

require "test_helper"

module Posting
  module Parts
    module Flows
      class DraftFlowTest < ActiveSupport::TestCase
        test "produces balanced entries for cash-only draft" do
          flow = DraftFlow.new(
            draft_amount_cents: 3_000,
            draft_fee_cents: 0,
            draft_cash_cents: 3_000,
            draft_account_cents: 0,
            check_items: [],
            primary_account_reference: "acct:123",
            cash_account_reference: "cash:D01",
            draft_liability_account_reference: "official_check:outstanding"
          )

          legs = flow.build_entries
          debit_total = legs.select { |l| l[:side] == "debit" }.sum { |l| l[:amount_cents] }
          credit_total = legs.select { |l| l[:side] == "credit" }.sum { |l| l[:amount_cents] }
          assert_equal debit_total, credit_total
        end

        test "raises when total payment does not equal total due" do
          flow = DraftFlow.new(
            draft_amount_cents: 3_000,
            draft_fee_cents: 100,
            draft_cash_cents: 3_000,
            draft_account_cents: 0,
            check_items: [],
            primary_account_reference: "acct:123",
            cash_account_reference: "cash:D01",
            draft_liability_account_reference: "official_check:outstanding"
          )

          assert_raises(PartBuilder::ValidationError) { flow.build_entries }
        end

        test "includes fee leg when draft_fee_cents positive" do
          flow = DraftFlow.new(
            draft_amount_cents: 3_000,
            draft_fee_cents: 100,
            draft_cash_cents: 3_100,
            draft_account_cents: 0,
            check_items: [],
            primary_account_reference: "acct:123",
            cash_account_reference: "cash:D01",
            draft_liability_account_reference: "official_check:outstanding",
            draft_fee_income_account_reference: "income:draft_fee"
          )

          legs = flow.build_entries
          assert legs.any? { |l| l[:account_reference] == "income:draft_fee" && l[:side] == "credit" && l[:amount_cents] == 100 }
        end
      end
    end
  end
end
