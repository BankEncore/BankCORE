require "test_helper"

module Posting
  class CommitterTest < ActiveSupport::TestCase
    setup do
      @user = User.take || User.create!(email_address: "posting-committer@example.com", password: "password")
      @branch = Branch.create!(code: "721", name: "Posting Committer Branch")
      @workstation = Workstation.create!(branch: @branch, code: "PC1", name: "Posting Committer WS")
      @drawer = CashLocation.create!(
        branch: @branch,
        code: "PCD1",
        name: "Posting Committer Drawer",
        location_type: "drawer"
      )
      @teller_session = TellerSession.create!(
        user: @user,
        branch: @branch,
        workstation: @workstation,
        cash_location: @drawer,
        status: "open",
        opened_at: Time.current,
        opening_cash_cents: 10_000
      )
    end

    test "persists posting records and returns committed batch" do
      request = {
        user: @user,
        teller_session: @teller_session,
        branch: @branch,
        workstation: @workstation,
        request_id: "commit-req-1",
        transaction_type: "deposit",
        amount_cents: 10_000,
        metadata: {},
        currency: "USD"
      }
      legs = [
        { side: "debit", account_reference: "cash:#{@drawer.code}", amount_cents: 10_000, position: 0 },
        { side: "credit", account_reference: "acct:deposit", amount_cents: 10_000, position: 1 }
      ]

      posting_batch = Committer.new(request: request, legs: legs).call

      assert_equal "committed", posting_batch.status
      assert_equal "commit-req-1", posting_batch.request_id
      assert_equal 2, posting_batch.posting_legs.count
      assert_equal 2, posting_batch.account_transactions.count
      assert_equal 1, posting_batch.teller_transaction.cash_movements.count
    end

    test "sets account_id when account_reference matches an Account" do
      account = Account.create!(
        account_number: "8888888888888888",
        account_type: "checking",
        branch: @branch,
        status: "open",
        opened_on: Date.current,
        last_activity_at: Time.current
      )

      request = {
        user: @user,
        teller_session: @teller_session,
        branch: @branch,
        workstation: @workstation,
        request_id: "commit-req-2",
        transaction_type: "deposit",
        amount_cents: 5_000,
        metadata: {},
        currency: "USD"
      }
      legs = [
        { side: "debit", account_reference: "cash:#{@drawer.code}", amount_cents: 5_000, position: 0 },
        { side: "credit", account_reference: account.account_number, amount_cents: 5_000, position: 1 }
      ]

      posting_batch = Committer.new(request: request, legs: legs).call

      credit_tx = posting_batch.account_transactions.find_by(direction: "credit")
      assert_equal account.id, credit_tx.account_id
      assert_nil posting_batch.account_transactions.find_by(direction: "debit").account_id
    end
  end
end
