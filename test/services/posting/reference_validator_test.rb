# frozen_string_literal: true

require "test_helper"

module Posting
  class ReferenceValidatorTest < ActiveSupport::TestCase
    setup do
      @branch = Branch.create!(code: "RV", name: "Ref Validator Branch")
      @account = Account.create!(
        account_number: "1111222233334444",
        account_type: "checking",
        branch: @branch,
        status: "open",
        opened_on: Date.current,
        last_activity_at: Time.current
      )
      @drawer = CashLocation.create!(
        branch: @branch,
        code: "RVD1",
        name: "Validator Drawer",
        location_type: "drawer"
      )
    end

    test "passes when all legs resolve" do
      legs = [
        { side: "debit", account_reference: "cash:#{@drawer.code}", amount_cents: 10_000 },
        { side: "credit", account_reference: "acct:#{@account.account_number}", amount_cents: 10_000 }
      ]
      assert_nothing_raised { ReferenceValidator.call(legs: legs) }
    end

    test "raises with error_class when reference is unknown" do
      legs = [
        { side: "debit", account_reference: "cash:#{@drawer.code}", amount_cents: 10_000 },
        { side: "credit", account_reference: "acct:nonexistent99999", amount_cents: 10_000 }
      ]
      err = assert_raises(Posting::Engine::Error) { ReferenceValidator.call(legs: legs) }
      assert_match(/Unknown account reference/, err.message)
      assert_includes err.message, "acct:nonexistent99999"
    end

    test "skips blank references" do
      legs = [
        { side: "debit", account_reference: "cash:#{@drawer.code}", amount_cents: 10_000 },
        { side: "credit", account_reference: "acct:#{@account.account_number}", amount_cents: 10_000 }
      ]
      assert_nothing_raised { ReferenceValidator.call(legs: legs) }
    end
  end
end
