# frozen_string_literal: true

require "test_helper"

class AccountTest < ActiveSupport::TestCase
  setup do
    @branch = Branch.first || Branch.create!(code: "001", name: "Main")
  end

  test "validates account_number uniqueness" do
    Account.create!(account_number: "1234567890123456", account_type: "checking", branch: @branch, status: "open", opened_on: Date.current, last_activity_at: Time.current)
    dup = Account.new(account_number: "1234567890123456", account_type: "checking", branch: @branch, status: "open", opened_on: Date.current, last_activity_at: Time.current)
    assert_not dup.valid?
    assert_includes dup.errors[:account_number], "has already been taken"
  end

  test "account_reference returns account_number" do
    account = Account.create!(account_number: "1000000000001001", account_type: "checking", branch: @branch, status: "open", opened_on: Date.current, last_activity_at: Time.current)
    assert_equal "1000000000001001", account.account_reference
  end

  test "validates status inclusion" do
    account = Account.new(account_number: "1234567890123456", account_type: "checking", branch: @branch, status: "invalid", opened_on: Date.current, last_activity_at: Time.current)
    assert_not account.valid?
    assert_includes account.errors[:status], "is not included in the list"
  end

  test "has_many account_transactions" do
    account = Account.create!(account_number: "5555555555555555", account_type: "checking", branch: @branch, status: "open", opened_on: Date.current, last_activity_at: Time.current)
    assert_empty account.account_transactions

    user = User.take || User.create!(email_address: "acct-test@example.com", password: "password")
    workstation = Workstation.find_or_create_by!(branch: @branch, code: "AT1") { |w| w.name = "Account Test WS" }
    drawer = CashLocation.find_or_create_by!(branch: @branch, code: "ATD1") do |cl|
      cl.name = "Account Test Drawer"
      cl.location_type = "drawer"
    end
    teller_session = TellerSession.create!(
      user: user,
      branch: @branch,
      workstation: workstation,
      cash_location: drawer,
      status: "open",
      opened_at: Time.current,
      opening_cash_cents: 0
    )
    teller_transaction = TellerTransaction.create!(
      user: user,
      teller_session: teller_session,
      branch: @branch,
      workstation: workstation,
      request_id: "acct-assoc-#{SecureRandom.hex(4)}",
      transaction_type: "deposit",
      currency: "USD",
      amount_cents: 1_000,
      status: "posted",
      posted_at: Time.current
    )
    posting_batch = PostingBatch.create!(
      teller_transaction: teller_transaction,
      request_id: teller_transaction.request_id,
      currency: "USD",
      status: "committed",
      committed_at: Time.current
    )
    account_tx = AccountTransaction.create!(
      teller_transaction: teller_transaction,
      posting_batch: posting_batch,
      account_reference: account.account_number,
      account_id: account.id,
      direction: "credit",
      amount_cents: 1_000
    )

    assert_includes account.account_transactions, account_tx
  end

  test "balance_cents returns credits minus debits" do
    account = Account.create!(account_number: "6666666666666666", account_type: "checking", branch: @branch, status: "open", opened_on: Date.current, last_activity_at: Time.current)
    assert_equal 0, account.balance_cents

    user = User.take || User.create!(email_address: "balance-test@example.com", password: "password")
    workstation = Workstation.find_or_create_by!(branch: @branch, code: "BL1") { |w| w.name = "Balance Test WS" }
    drawer = CashLocation.find_or_create_by!(branch: @branch, code: "BLD1") { |cl| cl.name = "Balance Drawer"; cl.location_type = "drawer" }
    teller_session = TellerSession.create!(user: user, branch: @branch, workstation: workstation, cash_location: drawer, status: "open", opened_at: Time.current, opening_cash_cents: 0)
    tt = TellerTransaction.create!(user: user, teller_session: teller_session, branch: @branch, workstation: workstation, request_id: "bal-#{SecureRandom.hex(4)}", transaction_type: "deposit", currency: "USD", amount_cents: 5_000, status: "posted", posted_at: Time.current)
    batch = PostingBatch.create!(teller_transaction: tt, request_id: tt.request_id, currency: "USD", status: "committed", committed_at: Time.current)

    AccountTransaction.create!(teller_transaction: tt, posting_batch: batch, account_reference: account.account_number, account_id: account.id, direction: "credit", amount_cents: 10_000)
    AccountTransaction.create!(teller_transaction: tt, posting_batch: batch, account_reference: account.account_number, account_id: account.id, direction: "debit", amount_cents: 3_000)

    assert_equal 7_000, account.balance_cents
  end
end
