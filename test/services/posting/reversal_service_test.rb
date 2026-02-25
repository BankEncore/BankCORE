require "test_helper"

module Posting
  class ReversalServiceTest < ActiveSupport::TestCase
    setup do
      @user = User.take || User.create!(email_address: "reversal-svc@example.com", password: "password")
      @branch = Branch.take || Branch.create!(code: "997", name: "Reversal Svc Branch")
      @workstation = Workstation.create!(branch: @branch, code: "RS1", name: "Reversal Svc WS")
      @drawer = CashLocation.create!(
        branch: @branch,
        code: "RSD1",
        name: "Reversal Svc Drawer",
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
      @original = create_deposit_transaction
    end

    test "creates reversal transaction and posting batch" do
      batch = ReversalService.new(
        user: @user,
        teller_session: @teller_session,
        branch: @branch,
        workstation: @workstation,
        original_teller_transaction_id: @original.id,
        reversal_reason_code: "ENTRY_ERROR",
        reversal_memo: "Wrong account entered",
        request_id: "reversal-#{@original.id}-#{Time.current.to_i}"
      ).call

      assert batch.is_a?(PostingBatch)
      assert_equal "reversal", batch.teller_transaction.transaction_type
      assert_equal @original.id, batch.teller_transaction.reversal_of_teller_transaction_id
      assert_equal "ENTRY_ERROR", batch.teller_transaction.reversal_reason_code
      assert_equal "Wrong account entered", batch.teller_transaction.reversal_memo
      assert_equal @original.posting_batch.id, batch.reversal_of_posting_batch_id

      @original.reload
      assert @original.reversed?
      assert_equal batch.teller_transaction.id, @original.reversed_by_teller_transaction_id
      assert @original.reversed_at.present?
    end

    test "stores approved_by_user_id when provided" do
      supervisor = User.create!(email_address: "reversal-supervisor@example.com", password: "password")
      batch = ReversalService.new(
        user: @user,
        teller_session: @teller_session,
        branch: @branch,
        workstation: @workstation,
        original_teller_transaction_id: @original.id,
        reversal_reason_code: "ENTRY_ERROR",
        reversal_memo: "Approved reversal",
        request_id: "reversal-approved-#{@original.id}-#{Time.current.to_i}",
        approved_by_user_id: supervisor.id
      ).call

      assert_equal supervisor.id, batch.teller_transaction.approved_by_user_id
      assert_equal supervisor, batch.teller_transaction.approved_by_user
    end

    test "reversal legs are inverted" do
      batch = ReversalService.new(
        user: @user,
        teller_session: @teller_session,
        branch: @branch,
        workstation: @workstation,
        original_teller_transaction_id: @original.id,
        reversal_reason_code: "DUPLICATE",
        reversal_memo: "Duplicate post",
        request_id: "reversal-inv-#{@original.id}-#{Time.current.to_i}"
      ).call

      original_legs = @original.posting_batch.posting_legs.order(:position)
      reversal_legs = batch.posting_legs.order(:position)

      assert_equal original_legs.size, reversal_legs.size
      original_legs.each_with_index do |orig, i|
        rev = reversal_legs[i]
        assert_equal orig.account_reference, rev.account_reference
        assert_equal orig.amount_cents, rev.amount_cents
        assert orig.side != rev.side, "Leg #{i} should have inverted side"
      end
    end

    test "creates cash movement with inverted direction for deposit reversal" do
      batch = ReversalService.new(
        user: @user,
        teller_session: @teller_session,
        branch: @branch,
        workstation: @workstation,
        original_teller_transaction_id: @original.id,
        reversal_reason_code: "OTHER",
        reversal_memo: "Test",
        request_id: "reversal-cash-#{@original.id}-#{Time.current.to_i}"
      ).call

      original_cash = @original.cash_movements.first
      reversal_cash = batch.teller_transaction.cash_movements.first

      assert original_cash.present?
      assert reversal_cash.present?
      assert_equal "in", original_cash.direction
      assert_equal "out", reversal_cash.direction
      assert_equal original_cash.amount_cents, reversal_cash.amount_cents
    end

    test "returns existing batch on idempotent retry" do
      request_id = "reversal-idem-#{@original.id}-#{Time.current.to_i}"
      batch1 = ReversalService.new(
        user: @user,
        teller_session: @teller_session,
        branch: @branch,
        workstation: @workstation,
        original_teller_transaction_id: @original.id,
        reversal_reason_code: "ENTRY_ERROR",
        reversal_memo: "Retry test",
        request_id: request_id
      ).call

      batch2 = ReversalService.new(
        user: @user,
        teller_session: @teller_session,
        branch: @branch,
        workstation: @workstation,
        original_teller_transaction_id: @original.id,
        reversal_reason_code: "OTHER",
        reversal_memo: "Different",
        request_id: request_id
      ).call

      assert_equal batch1.id, batch2.id
      assert_equal 1, TellerTransaction.where(reversal_of_teller_transaction_id: @original.id).count
    end

    private

    def create_deposit_transaction
      tt = TellerTransaction.create!(
        user: @user,
        teller_session: @teller_session,
        branch: @branch,
        workstation: @workstation,
        request_id: "deposit-svc-#{SecureRandom.hex(4)}",
        transaction_type: "deposit",
        amount_cents: 10_000,
        currency: "USD",
        status: "posted",
        posted_at: Time.current
      )
      pb = PostingBatch.create!(
        teller_transaction: tt,
        request_id: tt.request_id,
        currency: "USD",
        status: "committed",
        committed_at: Time.current,
        metadata: {}
      )
      PostingLeg.create!(posting_batch: pb, side: "debit", account_reference: "cash:#{@drawer.code}", amount_cents: 10_000, position: 0)
      PostingLeg.create!(posting_batch: pb, side: "credit", account_reference: "1000000000001001", amount_cents: 10_000, position: 1)
      CashMovement.create!(
        teller_transaction: tt,
        teller_session: @teller_session,
        cash_location: @drawer,
        direction: "in",
        amount_cents: 10_000
      )
      tt
    end
  end
end
