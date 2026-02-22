require "test_helper"

module Teller
  class TransactionHistoryControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = User.take
      @other_user = User.where.not(id: @user.id).first || User.create!(email_address: "history-other@example.com", password: "password")

      @branch = Branch.create!(code: "351", name: "History Branch")
      @workstation = Workstation.create!(branch: @branch, code: "H01", name: "History WS")
      @teller_session = TellerSession.create!(
        user: @user,
        branch: @branch,
        workstation: @workstation,
        opened_at: Time.current,
        opening_cash_cents: 10_000
      )

      grant_dashboard_access(@user, @branch, @workstation)
      grant_dashboard_access(@other_user, @branch, @workstation)
    end

    test "requires authentication" do
      get teller_history_path

      assert_redirected_to new_session_path
    end

    test "requires teller context before loading history" do
      sign_in_as(@user)

      get teller_history_path

      assert_redirected_to teller_context_path
    end

    test "shows only current teller transactions with receipt drilldown" do
      own_recent = create_posted_transaction!(
        user: @user,
        teller_session: @teller_session,
        request_id: "hist-req-001",
        amount_cents: 12_500,
        posted_at: Time.current
      )
      own_older = create_posted_transaction!(
        user: @user,
        teller_session: @teller_session,
        request_id: "hist-req-002",
        amount_cents: 5_000,
        posted_at: 1.hour.ago
      )

      other_session = TellerSession.create!(
        user: @other_user,
        branch: @branch,
        workstation: @workstation,
        opened_at: Time.current,
        opening_cash_cents: 8_000
      )
      create_posted_transaction!(
        user: @other_user,
        teller_session: other_session,
        request_id: "hist-req-999",
        amount_cents: 9_900,
        posted_at: 30.minutes.ago
      )

      sign_in_as(@user)
      patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }

      get teller_history_path

      assert_response :success
      assert_select "h2", "Transaction History"
      assert_select "td", text: /hist-req-001/
      assert_select "td", text: /hist-req-002/
      assert_select "td", text: /hist-req-999/, count: 0

      assert_select "a[href='#{teller_receipt_path(request_id: own_recent.request_id)}']", "View Receipt"
      assert_select "a[href='#{teller_receipt_path(request_id: own_older.request_id)}']", "View Receipt"
    end

    private
      def create_posted_transaction!(user:, teller_session:, request_id:, amount_cents:, posted_at:)
        transaction = TellerTransaction.create!(
          user: user,
          teller_session: teller_session,
          branch: teller_session.branch,
          workstation: teller_session.workstation,
          transaction_type: "deposit",
          amount_cents: amount_cents,
          currency: "USD",
          status: "posted",
          request_id: request_id,
          posted_at: posted_at
        )

        PostingBatch.create!(
          teller_transaction: transaction,
          request_id: request_id,
          currency: "USD",
          status: "committed",
          committed_at: posted_at
        )

        transaction
      end

      def grant_dashboard_access(user, branch, workstation)
        permission = Permission.find_or_create_by!(key: "teller.dashboard.view") do |record|
          record.description = "Access teller dashboard"
        end

        role = Role.find_or_create_by!(key: "teller") do |record|
          record.name = "Teller"
        end

        RolePermission.find_or_create_by!(role: role, permission: permission)
        UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: workstation)
      end
  end
end
