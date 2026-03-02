# frozen_string_literal: true

require "test_helper"

module Posting
  class LedgerBalanceUpdaterTest < ActiveSupport::TestCase
    setup do
      @branch = Branch.create!(code: "LB", name: "Ledger Balance Branch")
      @account = Account.create!(
        account_number: "1111111111111111",
        account_type: "checking",
        branch: @branch,
        status: "open",
        opened_on: Date.current,
        last_activity_at: Time.current,
        ledger_balance_cents: 0
      )
    end

    test "skips internal account references" do
      LedgerBalanceUpdater.call(legs: [
        { side: "credit", account_reference: "cash:DRAWER1", amount_cents: 10_000 },
        { side: "debit", account_reference: "income:fee", amount_cents: 10_000 }
      ])

      assert_equal 0, @account.reload.ledger_balance_cents
    end

    test "applies credit delta for customer account with raw account_number" do
      LedgerBalanceUpdater.call(legs: [
        { side: "credit", account_reference: @account.account_number, amount_cents: 25_000 }
      ])

      assert_equal 25_000, @account.reload.ledger_balance_cents
    end

    test "applies debit delta (negative) for customer account" do
      @account.update!(ledger_balance_cents: 50_000)

      LedgerBalanceUpdater.call(legs: [
        { side: "debit", account_reference: @account.account_number, amount_cents: 15_000 }
      ])

      assert_equal 35_000, @account.reload.ledger_balance_cents
    end

    test "normalizes acct: prefix to resolve account" do
      LedgerBalanceUpdater.call(legs: [
        { side: "credit", account_reference: "acct:#{@account.account_number}", amount_cents: 10_000 }
      ])

      assert_equal 10_000, @account.reload.ledger_balance_cents
    end

    test "aggregates multiple legs for same account" do
      LedgerBalanceUpdater.call(legs: [
        { side: "credit", account_reference: @account.account_number, amount_cents: 20_000 },
        { side: "debit", account_reference: @account.account_number, amount_cents: 5_000 }
      ])

      assert_equal 15_000, @account.reload.ledger_balance_cents
    end

    test "updates ledger_balance_updated_at" do
      freeze_time do
        LedgerBalanceUpdater.call(legs: [
          { side: "credit", account_reference: @account.account_number, amount_cents: 1_000 }
        ])

        assert_equal Time.current, @account.reload.ledger_balance_updated_at
      end
    end

    test "handles mixed legs: updates only customer accounts" do
      other_account = Account.create!(
        account_number: "2222222222222222",
        account_type: "checking",
        branch: @branch,
        status: "open",
        opened_on: Date.current,
        last_activity_at: Time.current,
        ledger_balance_cents: 0
      )

      LedgerBalanceUpdater.call(legs: [
        { side: "debit", account_reference: "cash:D1", amount_cents: 30_000 },
        { side: "credit", account_reference: @account.account_number, amount_cents: 20_000 },
        { side: "credit", account_reference: other_account.account_number, amount_cents: 10_000 }
      ])

      assert_equal 20_000, @account.reload.ledger_balance_cents
      assert_equal 10_000, other_account.reload.ledger_balance_cents
    end

    test "no-op when legs empty" do
      LedgerBalanceUpdater.call(legs: [])

      assert_equal 0, @account.reload.ledger_balance_cents
    end

    test "no-op when no customer account legs" do
      LedgerBalanceUpdater.call(legs: [
        { side: "debit", account_reference: "check:111:222:333", amount_cents: 100 },
        { side: "credit", account_reference: "official_check:outstanding", amount_cents: 100 }
      ])

      assert_equal 0, @account.reload.ledger_balance_cents
    end
  end
end
