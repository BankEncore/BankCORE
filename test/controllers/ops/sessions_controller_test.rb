require "test_helper"

module Ops
  class SessionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = User.take
      @branch = Branch.create!(code: "901", name: "Ops Branch")
      @workstation = Workstation.create!(branch: @branch, code: "OPS1", name: "Ops WS")
      @drawer = CashLocation.create!(
        branch: @branch,
        code: "ODR1",
        name: "Ops Drawer",
        location_type: "drawer"
      )
      @teller_session = TellerSession.create!(
        user: @user,
        branch: @branch,
        workstation: @workstation,
        cash_location: @drawer,
        status: "closed",
        opened_at: 1.hour.ago,
        closed_at: Time.current,
        opening_cash_cents: 5_000,
        closing_cash_cents: 5_150,
        expected_closing_cash_cents: 5_150
      )
      sign_in_as(@user)
    end

    test "index requires authentication" do
      sign_out
      get ops_sessions_path
      assert_redirected_to new_session_path
    end

    test "index shows sessions with filters" do
      get ops_sessions_path, params: { branch_id: @branch.id, date_from: Date.current, date_to: Date.current }

      assert_response :success
      assert_select "h2", "Teller Sessions"
      assert_select "table"
      assert_select "a", "Detail"
    end

    test "index with no matching sessions" do
      get ops_sessions_path, params: { branch_id: @branch.id, date_from: 1.year.ago, date_to: 1.year.ago }

      assert_response :success
      assert_select "h2", "Teller Sessions"
      assert_select "td", "No sessions match the selected filters."
    end

    test "show displays session detail" do
      get ops_session_path(@teller_session)

      assert_response :success
      assert_select "h2", /Session #{@teller_session.id}/
      assert_select "dt", "Teller"
      assert_select "dt", "Opening cash"
      assert_select "h3", "Cash Reconciliation"
      assert_select "h3", "Transactions"
    end

    test "show displays transactions when present" do
      TellerTransaction.create!(
        user: @user,
        teller_session: @teller_session,
        branch: @branch,
        workstation: @workstation,
        request_id: "ops-test-1",
        transaction_type: "deposit",
        amount_cents: 100,
        currency: "USD",
        status: "posted",
        posted_at: Time.current
      )

      get ops_session_path(@teller_session)

      assert_response :success
      assert_select "table tbody tr", minimum: 1
    end
  end
end
