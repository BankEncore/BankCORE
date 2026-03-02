# frozen_string_literal: true

require "test_helper"

class LedgerBalanceTasksTest < ActiveSupport::TestCase
  setup do
    @branch = Branch.create!(code: "LBT", name: "Ledger Balance Tasks Branch")
  end

  test "validate reports no diffs when cached matches computed" do
    account = Account.create!(
      account_number: "4444444444444444",
      account_type: "checking",
      branch: @branch,
      status: "open",
      opened_on: Date.current,
      last_activity_at: Time.current,
      ledger_balance_cents: 0
    )
    assert_equal 0, account.ledger_balance_cents

    LedgerBalanceTasks.validate
    # No exception; validation completes
  end

  test "rebuild repairs mismatched ledger_balance_cents" do
    account = Account.create!(
      account_number: "5555555555555555",
      account_type: "checking",
      branch: @branch,
      status: "open",
      opened_on: Date.current,
      last_activity_at: Time.current,
      ledger_balance_cents: 0
    )
    user = User.take || User.create!(email_address: "lbt@example.com", password: "password")
    workstation = Workstation.create!(branch: @branch, code: "LBT1", name: "LBT WS")
    drawer = CashLocation.create!(branch: @branch, code: "LBTD1", name: "LBT Drawer", location_type: "drawer")
    teller_session = TellerSession.create!(
      user: user,
      branch: @branch,
      workstation: workstation,
      cash_location: drawer,
      status: "open",
      opened_at: Time.current,
      opening_cash_cents: 0
    )
    tt = TellerTransaction.create!(
      user: user,
      teller_session: teller_session,
      branch: @branch,
      workstation: workstation,
      request_id: "lbt-#{SecureRandom.hex(4)}",
      transaction_type: "deposit",
      currency: "USD",
      amount_cents: 33_000,
      status: "posted",
      posted_at: Time.current
    )
    batch = PostingBatch.create!(teller_transaction: tt, request_id: tt.request_id, currency: "USD", status: "committed", committed_at: Time.current)
    AccountTransaction.create!(
      teller_transaction: tt,
      posting_batch: batch,
      account_reference: account.account_number,
      account_id: account.id,
      direction: "credit",
      amount_cents: 33_000
    )
    # Cache is wrong (stale at 0)
    account.update_columns(ledger_balance_cents: 0)

    LedgerBalanceTasks.rebuild(repair: true)

    assert_equal 33_000, account.reload.ledger_balance_cents
  end

  test "rebuild with repair false does not update cached value" do
    account = Account.create!(
      account_number: "6666666666666666",
      account_type: "checking",
      branch: @branch,
      status: "open",
      opened_on: Date.current,
      last_activity_at: Time.current,
      ledger_balance_cents: 999
    )
    # No transactions, so computed is 0 but cached is 999

    LedgerBalanceTasks.rebuild(repair: false)

    assert_equal 999, account.reload.ledger_balance_cents
  end
end
