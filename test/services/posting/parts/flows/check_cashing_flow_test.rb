# frozen_string_literal: true

require "test_helper"

module Posting
  module Parts
    module Flows
      class CheckCashingFlowTest < ActiveSupport::TestCase
        test "produces balanced entries" do
          parts = TransactionParts.new(
            check_items: [ { routing: "021", account: "123", number: "100", account_reference: "check:021:123:100", amount_cents: 10_000 } ],
            fee_cents: 500,
            cash_account_reference: "cash:D01",
            fee_income_account_reference: "income:check_cashing_fee"
          )
          flow = CheckCashingFlow.new(transaction_parts: parts)

          legs = flow.build_entries
          debit_total = legs.select { |l| l[:side] == "debit" }.sum { |l| l[:amount_cents] }
          credit_total = legs.select { |l| l[:side] == "credit" }.sum { |l| l[:amount_cents] }
          assert_equal debit_total, credit_total
        end

        test "validate! raises when FEE > CK" do
          parts = TransactionParts.new(
            check_items: [ { routing: "021", account: "123", number: "100", account_reference: "check:021:123:100", amount_cents: 1_000 } ],
            fee_cents: 2_000,
            cash_account_reference: "cash:D01",
            fee_income_account_reference: "income:check_cashing_fee"
          )
          flow = CheckCashingFlow.new(transaction_parts: parts)

          assert_raises(PartBuilder::ValidationError) { flow.validate! }
        end
      end
    end
  end
end
