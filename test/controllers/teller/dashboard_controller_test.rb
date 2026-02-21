require "test_helper"

module Teller
  class DashboardControllerTest < ActionDispatch::IntegrationTest
    test "requires authentication" do
      get teller_root_path
      assert_redirected_to new_session_path
    end

    test "denies dashboard without permission" do
      sign_in_as(User.take)

      get teller_root_path

      assert_redirected_to root_path
      follow_redirect!
      assert_select "div", /not authorized/i
    end

    test "shows dashboard for user with permission" do
      user = User.take
      grant_teller_dashboard_access(user)
      sign_in_as(user)

      get teller_root_path

      assert_response :success
      assert_select "h2", "Teller Transaction Flows"
    end

    test "shows transaction flow launcher when session and drawer are available" do
      user = User.take
      branch = Branch.create!(code: "031", name: "Posting UI Branch")
      workstation = Workstation.create!(branch: branch, code: "P01", name: "Posting UI WS")
      drawer = CashLocation.create!(branch: branch, code: "PD1", name: "Posting UI Drawer", location_type: "drawer")

      grant_teller_dashboard_access(user, branch: branch, workstation: workstation)
      grant_posting_access(user, branch: branch, workstation: workstation)
      sign_in_as(user)
      patch teller_context_path, params: { branch_id: branch.id, workstation_id: workstation.id }
      post teller_teller_session_path, params: { opening_cash_cents: 1_000 }
      patch assign_drawer_teller_teller_session_path, params: { cash_location_id: drawer.id }

      get teller_root_path

      assert_response :success
      assert_select "h2", "Transaction Flows"
      assert_select "a[href='#{new_teller_deposit_path}']", "Deposit"
      assert_select "a[href='#{new_teller_withdrawal_path}']", "Withdrawal"
      assert_select "a[href='#{new_teller_check_cashing_path}']", "Check Cashing"
      assert_select "a[href='#{new_teller_transfer_path}']", "Transfer"
      assert_select "div#posting-workspace", count: 0
    end

    test "shows context setup page" do
      user = User.take
      branch = Branch.create!(code: "211", name: "Context Branch")
      workstation = Workstation.create!(branch: branch, code: "CTX1", name: "Context WS")
      grant_teller_dashboard_access(user, branch: branch, workstation: workstation)
      sign_in_as(user)

      get teller_context_path

      assert_response :success
      assert_select "h2", "Teller Environment & Session"
      assert_select "h2", "Session Context"
      assert_select "h2", "Teller Session"
      assert_select "form[action='#{teller_context_path}'][method='post']"
    end

    test "updates context with valid branch and workstation" do
      user = User.take
      branch = Branch.create!(code: "011", name: "Main Branch")
      workstation = Workstation.create!(branch: branch, code: "T11", name: "Teller 01")
      grant_teller_dashboard_access(user, branch: branch, workstation: workstation)
      sign_in_as(user)

      patch teller_context_path, params: { branch_id: branch.id, workstation_id: workstation.id }

      assert_redirected_to teller_context_path
      follow_redirect!
      assert_response :success
      assert_select "p", /Branch:\s+Main Branch/
      assert_select "p", /Workstation:\s+Teller 01/
    end

    test "rejects workstation from another branch" do
      user = User.take
      branch = Branch.create!(code: "012", name: "Main Branch")
      other_branch = Branch.create!(code: "013", name: "North Branch")
      workstation = Workstation.create!(branch: other_branch, code: "T12", name: "North Teller")
      grant_teller_dashboard_access(user, branch: branch)
      sign_in_as(user)

      patch teller_context_path, params: { branch_id: branch.id, workstation_id: workstation.id }

      assert_redirected_to teller_context_path
      follow_redirect!
      assert_response :success
      assert_select "div", /Workstation must belong to selected branch/
    end

    private
      def grant_teller_dashboard_access(user, branch: nil, workstation: nil)
        permission = Permission.find_or_create_by!(key: "teller.dashboard.view") do |record|
          record.description = "Access teller dashboard"
        end

        role = Role.find_or_create_by!(key: "teller") do |record|
          record.name = "Teller"
        end

        RolePermission.find_or_create_by!(role: role, permission: permission)
        UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: workstation)
      end

      def grant_posting_access(user, branch:, workstation:)
        [ "transactions.deposit.create", "sessions.open" ].each do |permission_key|
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
