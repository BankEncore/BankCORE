require "test_helper"

module Posting
  class EngineTest < ActiveSupport::TestCase
    setup do
      @user = User.take || User.create!(email_address: "posting-engine@example.com", password: "password")
      @branch = Branch.create!(code: "301", name: "Posting Engine Branch")
      @workstation = Workstation.create!(branch: @branch, code: "PE1", name: "Posting Engine WS")
      @drawer = CashLocation.create!(
        branch: @branch,
        code: "PED1",
        name: "Posting Engine Drawer",
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

    test "creates balanced posting records" do
      batch = build_engine(request_id: "req-balanced-1").call

      assert_equal "committed", batch.status
      assert_equal 2, batch.posting_legs.count
      assert_equal 2, batch.account_transactions.count
      assert_equal 1, CashMovement.where(teller_transaction_id: batch.teller_transaction_id).count
    end

    test "does not create cash movement for check-only deposit" do
      entries = [
        { side: "debit", account_reference: "check:#{SecureRandom.hex(4)}", amount_cents: 10_000 },
        { side: "credit", account_reference: "acct:deposit", amount_cents: 10_000 }
      ]

      batch = build_engine(request_id: "req-check-only-1", entries: entries).call

      assert_equal 0, CashMovement.where(teller_transaction_id: batch.teller_transaction_id).count
    end

    test "allows transfer posting without assigned drawer" do
      session_without_drawer = TellerSession.create!(
        user: @user,
        branch: @branch,
        workstation: @workstation,
        cash_location: nil,
        status: "open",
        opened_at: Time.current,
        opening_cash_cents: 10_000
      )

      engine = build_engine(
        request_id: "req-transfer-no-drawer-1",
        teller_session: session_without_drawer,
        transaction_type: "transfer",
        amount_cents: 5_00,
        entries: [
          { side: "debit", account_reference: "acct:from", amount_cents: 5_00 },
          { side: "credit", account_reference: "acct:to", amount_cents: 5_00 }
        ]
      )

      batch = engine.call

      assert_equal "committed", batch.status
      assert_equal 0, CashMovement.where(teller_transaction_id: batch.teller_transaction_id).count
    end

    test "raises when posting is unbalanced" do
      engine = build_engine(
        request_id: "req-unbalanced-1",
        entries: [
          { side: "debit", account_reference: "acct:cash", amount_cents: 10_000 },
          { side: "credit", account_reference: "acct:deposit", amount_cents: 9_500 }
        ]
      )

      assert_raises(Posting::Engine::Error) { engine.call }
      assert_equal 0, TellerTransaction.where(request_id: "req-unbalanced-1").count
      assert_equal 0, PostingBatch.where(request_id: "req-unbalanced-1").count
    end

    test "returns existing batch for duplicate request id" do
      first = build_engine(request_id: "req-idempotent-1").call
      second = build_engine(request_id: "req-idempotent-1").call

      assert_equal first.id, second.id
      assert_equal 1, PostingBatch.where(request_id: "req-idempotent-1").count
      assert_equal 1, TellerTransaction.where(request_id: "req-idempotent-1").count
    end

    private
      def build_engine(request_id:, entries: default_entries, teller_session: @teller_session, transaction_type: "deposit", amount_cents: 10_000)
        Posting::Engine.new(
          user: @user,
          teller_session: teller_session,
          branch: @branch,
          workstation: @workstation,
          request_id: request_id,
          transaction_type: transaction_type,
          amount_cents: amount_cents,
          entries: entries
        )
      end

      def default_entries
        [
          { side: "debit", account_reference: "cash:#{@drawer.code}", amount_cents: 10_000 },
          { side: "credit", account_reference: "acct:deposit", amount_cents: 10_000 }
        ]
      end
  end
end
