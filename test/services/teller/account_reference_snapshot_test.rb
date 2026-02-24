# frozen_string_literal: true

require "test_helper"

module Teller
  class AccountReferenceSnapshotTest < ActiveSupport::TestCase
    setup do
      @branch = Branch.create!(code: "ARS", name: "Snapshot Branch")
      @account = Account.create!(
        account_number: "7777777777777777",
        account_type: "checking",
        branch: @branch,
        status: "open",
        opened_on: Date.current,
        last_activity_at: Time.current
      )
    end

    test "uses account_id when reference matches an Account" do
      workstation = Workstation.create!(branch: @branch, code: "W1", name: "WS1")
      teller_session = TellerSession.create!(
        user: User.take,
        branch: @branch,
        workstation: workstation,
        status: "open",
        opened_at: Time.current,
        opening_cash_cents: 0
      )
      tt = TellerTransaction.create!(
        user: User.take,
        teller_session: teller_session,
        branch: @branch,
        workstation: workstation,
        request_id: "snap-1",
        transaction_type: "deposit",
        amount_cents: 50_000,
        currency: "USD",
        posted_at: Time.current,
        status: "posted"
      )
      batch = PostingBatch.create!(
        teller_transaction: tt,
        request_id: "snap-1",
        currency: "USD",
        status: "committed",
        committed_at: Time.current
      )
      AccountTransaction.create!(
        teller_transaction: tt,
        posting_batch: batch,
        account_reference: @account.account_number,
        account_id: @account.id,
        direction: "credit",
        amount_cents: 50_000
      )

      result = AccountReferenceSnapshot.new(reference: @account.account_number).call

      assert result[:ok]
      assert result[:found]
      assert_equal 50_000, result[:ledger_balance_cents]
      assert_equal 50_000, result[:total_credits_cents]
    end

    test "uses account_id after account_number change so balance persists" do
      workstation = Workstation.create!(branch: @branch, code: "W2", name: "WS2")
      teller_session = TellerSession.create!(
        user: User.take,
        branch: @branch,
        workstation: workstation,
        status: "open",
        opened_at: Time.current,
        opening_cash_cents: 0
      )
      tt = TellerTransaction.create!(
        user: User.take,
        teller_session: teller_session,
        branch: @branch,
        workstation: workstation,
        request_id: "snap-2",
        transaction_type: "deposit",
        amount_cents: 25_000,
        currency: "USD",
        posted_at: Time.current,
        status: "posted"
      )
      batch = PostingBatch.create!(
        teller_transaction: tt,
        request_id: "snap-2",
        currency: "USD",
        status: "committed",
        committed_at: Time.current
      )
      AccountTransaction.create!(
        teller_transaction: tt,
        posting_batch: batch,
        account_reference: "1111111111111111",
        account_id: @account.id,
        direction: "credit",
        amount_cents: 25_000
      )

      @account.update!(account_number: "9999999999999999")

      result = AccountReferenceSnapshot.new(reference: "9999999999999999").call

      assert result[:ok]
      assert result[:found]
      assert_equal 25_000, result[:ledger_balance_cents]
    end

    test "uses account_reference when reference does not match an Account" do
      workstation = Workstation.create!(branch: @branch, code: "W3", name: "WS3")
      teller_session = TellerSession.create!(
        user: User.take,
        branch: @branch,
        workstation: workstation,
        status: "open",
        opened_at: Time.current,
        opening_cash_cents: 0
      )
      tt = TellerTransaction.create!(
        user: User.take,
        teller_session: teller_session,
        branch: @branch,
        workstation: workstation,
        request_id: "snap-3",
        transaction_type: "deposit",
        amount_cents: 10_000,
        currency: "USD",
        posted_at: Time.current,
        status: "posted"
      )
      batch = PostingBatch.create!(
        teller_transaction: tt,
        request_id: "snap-3",
        currency: "USD",
        status: "committed",
        committed_at: Time.current
      )
      AccountTransaction.create!(
        teller_transaction: tt,
        posting_batch: batch,
        account_reference: "cash:DRAWER1",
        account_id: nil,
        direction: "credit",
        amount_cents: 10_000
      )

      result = AccountReferenceSnapshot.new(reference: "cash:DRAWER1").call

      assert result[:ok]
      assert result[:found]
      assert_equal 10_000, result[:ledger_balance_cents]
    end
  end
end
