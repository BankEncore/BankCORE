require "test_helper"

module Teller
  class TransactionPagesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = User.take
      @branch = Branch.create!(code: "741", name: "Flow Branch")
      @workstation = Workstation.create!(branch: @branch, code: "FW1", name: "Flow WS")
      @drawer = CashLocation.create!(
        branch: @branch,
        code: "FDR1",
        name: "Flow Drawer",
        location_type: "drawer"
      )
    end

    test "requires authentication" do
      get teller_deposit_transaction_path

      assert_redirected_to new_session_path
    end

    test "denies flow page without posting permission" do
      sign_in_as(@user)

      get teller_deposit_transaction_path

      assert_redirected_to root_path
    end

    test "redirects to dashboard when posting context is missing" do
      grant_posting_access(@user, @branch, @workstation)
      sign_in_as(@user)
      patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }

      get teller_deposit_transaction_path

      assert_redirected_to teller_context_path
      follow_redirect!
      assert_select "div", /Open a teller session before posting transactions/i
    end

    test "renders split flow pages with fixed transaction type" do
      grant_posting_access(@user, @branch, @workstation)
      sign_in_as(@user)
      patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }
      post teller_teller_session_path, params: { opening_cash_cents: 10_000 }
      patch assign_drawer_teller_teller_session_path, params: { cash_location_id: @drawer.id }

      get teller_deposit_transaction_path
      assert_response :success
      assert_select "h2", "Deposit"
      assert_select "h2", "Reference Summary"
      assert_select "p", /Session Context/
      assert_select "p", /Transaction Snapshot/
      assert_select "p", /Amounts/
      assert_select "p", /Cash Impact/
      assert_select "p", /Posting Readiness/
      assert_select "p", text: /Primary Account History/, count: 0
      assert_select "input[name='transaction_type'][value='deposit']", count: 1
      assert_select "section[data-posting-form-target='checkSection']:not([hidden])", count: 1
      assert_select "p[data-posting-form-target='cashAccountRow']", count: 0
      assert_select "input[type='hidden'][name='cash_account_reference'][value='cash:#{@drawer.code}']", count: 1
      assert_select "p[data-posting-form-target='counterpartyRow'][hidden]", count: 1

      get teller_withdrawal_transaction_path
      assert_response :success
      assert_select "h2", "Withdrawal"
      assert_select "input[name='transaction_type'][value='withdrawal']", count: 1
      assert_select "section[data-posting-form-target='checkSection'][hidden]", count: 1
      assert_select "p[data-posting-form-target='cashAccountRow']", count: 0
      assert_select "input[type='hidden'][name='cash_account_reference'][value='cash:#{@drawer.code}']", count: 1
      assert_select "p[data-posting-form-target='counterpartyRow'][hidden]", count: 1

      get teller_transfer_transaction_path
      assert_response :success
      assert_select "h2", "Transfer"
      assert_select "input[name='transaction_type'][value='transfer']", count: 1
      assert_select "section[data-posting-form-target='checkSection'][hidden]", count: 1
      assert_select "p[data-posting-form-target='cashAccountRow']", count: 0
      assert_select "input[type='hidden'][name='cash_account_reference'][value='cash:#{@drawer.code}']", count: 1
      assert_select "p[data-posting-form-target='counterpartyRow']:not([hidden])", count: 1
    end

    private
      def grant_posting_access(user, branch, workstation)
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
