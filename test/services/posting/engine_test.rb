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
      def build_engine(request_id:, entries: default_entries)
        Posting::Engine.new(
          user: @user,
          teller_session: @teller_session,
          branch: @branch,
          workstation: @workstation,
          request_id: request_id,
          transaction_type: "deposit",
          amount_cents: 10_000,
          entries: entries
        )
      end

      def default_entries
        [
          { side: "debit", account_reference: "acct:cash", amount_cents: 10_000 },
          { side: "credit", account_reference: "acct:deposit", amount_cents: 10_000 }
        ]
      end
  end
end
