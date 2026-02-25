require "test_helper"

module Posting
  class ReversalRecipeBuilderTest < ActiveSupport::TestCase
    setup do
      @user = User.take || User.create!(email_address: "reversal-recipe@example.com", password: "password")
      @branch = Branch.take || Branch.create!(code: "998", name: "Recipe Branch")
      @workstation = Workstation.create!(branch: @branch, code: "RR1", name: "Recipe WS")
      @drawer = CashLocation.create!(
        branch: @branch,
        code: "RRD1",
        name: "Recipe Drawer",
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

    test "returns inverted legs with swapped debit/credit" do
      entries = ReversalRecipeBuilder.new(original_teller_transaction: @original).entries

      assert_equal 2, entries.size
      assert_equal "credit", entries[0][:side]
      assert_equal "debit", entries[1][:side]
      assert_equal @original.posting_batch.posting_legs.order(:position).first.account_reference, entries[0][:account_reference]
      assert_equal @original.posting_batch.posting_legs.order(:position).last.account_reference, entries[1][:account_reference]
      assert_equal 10_000, entries[0][:amount_cents]
      assert_equal 10_000, entries[1][:amount_cents]
    end

    test "raises when original is not reversible" do
      variance = TellerTransaction.create!(
        user: @user,
        teller_session: @teller_session,
        branch: @branch,
        workstation: @workstation,
        request_id: "variance-#{SecureRandom.hex(4)}",
        transaction_type: "session_close_variance",
        amount_cents: 100,
        currency: "USD",
        status: "posted",
        posted_at: Time.current
      )
      pb = PostingBatch.create!(
        teller_transaction: variance,
        request_id: variance.request_id,
        currency: "USD",
        status: "committed",
        committed_at: Time.current,
        metadata: {}
      )
      PostingLeg.create!(posting_batch: pb, side: "debit", account_reference: "cash:#{@drawer.code}", amount_cents: 100, position: 0)
      PostingLeg.create!(posting_batch: pb, side: "credit", account_reference: "income:variance", amount_cents: 100, position: 1)

      assert_raises(ReversalRecipeBuilder::Error) do
        ReversalRecipeBuilder.new(original_teller_transaction: variance).entries
      end
    end

    test "raises when original is already reversed" do
      reversal_tt = TellerTransaction.create!(
        user: @user,
        teller_session: @teller_session,
        branch: @branch,
        workstation: @workstation,
        request_id: "reversal-#{SecureRandom.hex(4)}",
        transaction_type: "reversal",
        amount_cents: 10_000,
        currency: "USD",
        status: "posted",
        posted_at: Time.current
      )
      @original.update!(reversed_by_teller_transaction_id: reversal_tt.id)

      assert_raises(ReversalRecipeBuilder::Error) do
        ReversalRecipeBuilder.new(original_teller_transaction: @original).entries
      end
    end

    private

    def create_deposit_transaction
      tt = TellerTransaction.create!(
        user: @user,
        teller_session: @teller_session,
        branch: @branch,
        workstation: @workstation,
        request_id: "deposit-#{SecureRandom.hex(4)}",
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
      tt
    end
  end
end
