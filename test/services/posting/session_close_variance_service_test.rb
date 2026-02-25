require "test_helper"

module Posting
  class SessionCloseVarianceServiceTest < ActiveSupport::TestCase
    setup do
      @user = User.take
      @branch = Branch.create!(code: "101", name: "Branch")
      @workstation = Workstation.create!(branch: @branch, code: "WS1", name: "WS1")
      @drawer = CashLocation.create!(
        branch: @branch,
        code: "DR1",
        name: "Drawer 1",
        location_type: "drawer"
      )
      @session = TellerSession.create!(
        user: @user,
        branch: @branch,
        workstation: @workstation,
        cash_location: @drawer,
        status: "open",
        opened_at: Time.current,
        opening_cash_cents: 5_000
      )
    end

    test "creates transaction with variance amount when short" do
      service = SessionCloseVarianceService.new(
        teller_session: @session,
        declared_cents: 4_800,
        expected_cents: 5_000,
        variance_reason: "short"
      )
      service.call

      tx = TellerTransaction.find_by(teller_session: @session, transaction_type: "session_close_variance")
      assert_not_nil tx
      assert_equal 200, tx.amount_cents
    end

    test "creates transaction with variance amount when over" do
      service = SessionCloseVarianceService.new(
        teller_session: @session,
        declared_cents: 5_200,
        expected_cents: 5_000,
        variance_reason: "over"
      )
      service.call

      tx = TellerTransaction.find_by(teller_session: @session, transaction_type: "session_close_variance")
      assert_not_nil tx
      assert_equal 200, tx.amount_cents
    end
  end
end
