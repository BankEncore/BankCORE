require "test_helper"

module Teller
  class TypedCreatesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = User.take
      @branch = Branch.create!(code: "881", name: "Typed Branch")
      @workstation = Workstation.create!(branch: @branch, code: "TC1", name: "Typed WS")
      @drawer = CashLocation.create!(
        branch: @branch,
        code: "TDR1",
        name: "Typed Drawer",
        location_type: "drawer"
      )

      grant_permissions(@user, @branch, @workstation)
      sign_in_as(@user)
      patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }
      post teller_teller_session_path, params: { opening_cash_cents: 5_000 }
      patch assign_drawer_teller_teller_session_path, params: { cash_location_id: @drawer.id }
    end

    test "deposit create enforces deposit transaction type" do
      post teller_deposits_path, params: {
        request_id: "typed-dep-1",
        transaction_type: "transfer",
        amount_cents: 12_000,
        primary_account_reference: "acct:dep",
        cash_account_reference: "cash:spoofed"
      }

      assert_response :success
      transaction = TellerTransaction.find_by!(request_id: "typed-dep-1")
      assert_equal "deposit", transaction.transaction_type
      assert_equal "cash:#{@drawer.code}", transaction.posting_batch.posting_legs.find_by!(side: "debit").account_reference
    end

    test "withdrawal create enforces withdrawal transaction type" do
      post teller_withdrawals_path, params: {
        request_id: "typed-wd-1",
        transaction_type: "deposit",
        amount_cents: 9_000,
        primary_account_reference: "acct:wd",
        cash_account_reference: "cash:spoofed"
      }

      assert_response :success
      transaction = TellerTransaction.find_by!(request_id: "typed-wd-1")
      assert_equal "withdrawal", transaction.transaction_type
      assert_equal "cash:#{@drawer.code}", transaction.posting_batch.posting_legs.find_by!(side: "credit").account_reference
    end

    test "transfer create enforces transfer transaction type" do
      post teller_transfers_path, params: {
        request_id: "typed-tr-1",
        transaction_type: "deposit",
        amount_cents: 8_000,
        primary_account_reference: "acct:from",
        counterparty_account_reference: "acct:to"
      }

      assert_response :success
      assert_equal "transfer", TellerTransaction.find_by!(request_id: "typed-tr-1").transaction_type
    end

    private
      def grant_permissions(user, branch, workstation)
        [ "teller.dashboard.view", "transactions.deposit.create", "sessions.open" ].each do |permission_key|
          permission = Permission.find_or_create_by!(key: permission_key) do |record|
            record.description = permission_key.humanize
          end

          role = Role.find_or_create_by!(key: "teller") do |record|
            record.name = "Teller"
          end

          RolePermission.find_or_create_by!(role: role, permission: permission)
          UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: workstation)
        end
      end
  end
end
