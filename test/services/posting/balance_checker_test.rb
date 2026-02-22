require "test_helper"

module Posting
  class BalanceCheckerTest < ActiveSupport::TestCase
    class BalanceError < StandardError; end

    test "raises when legs are unbalanced" do
      legs = [
        { side: "debit", amount_cents: 1_000 },
        { side: "credit", amount_cents: 900 }
      ]

      error = assert_raises(BalanceError) do
        BalanceChecker.call(legs: legs, error_class: BalanceError)
      end

      assert_equal "posting legs are unbalanced", error.message
    end

    test "passes when legs are balanced" do
      legs = [
        { side: "debit", amount_cents: 1_000 },
        { side: "credit", amount_cents: 1_000 }
      ]

      assert_nothing_raised do
        BalanceChecker.call(legs: legs, error_class: BalanceError)
      end
    end
  end
end
