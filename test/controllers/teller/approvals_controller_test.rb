require "test_helper"

module Teller
  class ApprovalsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = User.take
      @supervisor = User.create!(email_address: "supervisor-approval@example.com", password: "password")
      @branch = Branch.create!(code: "601", name: "Approval Branch")
      @workstation = Workstation.create!(branch: @branch, code: "AW1", name: "Approval WS")
      @drawer = CashLocation.create!(
        branch: @branch,
        code: "ADR1",
        name: "Approval Drawer",
        location_type: "drawer"
      )

      grant_teller_permissions(@user, @branch, @workstation)
      grant_supervisor_permissions(@supervisor, @branch, @workstation)
      sign_in_as(@user)
      patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }
      post teller_teller_session_path, params: { opening_cash_cents: 10_000 }
      patch assign_drawer_teller_teller_session_path, params: { cash_location_id: @drawer.id }
    end

    test "creates approval token with valid supervisor credentials" do
      post teller_approvals_path, params: {
        request_id: "approval-1",
        reason: "threshold_exceeded",
        supervisor_email_address: @supervisor.email_address,
        supervisor_password: "password"
      }

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal true, body["ok"]
      assert body["approval_token"].present?
    end

    test "rejects invalid supervisor credentials" do
      post teller_approvals_path, params: {
        request_id: "approval-2",
        reason: "threshold_exceeded",
        supervisor_email_address: @supervisor.email_address,
        supervisor_password: "wrong"
      }

      assert_response :unauthorized
      body = JSON.parse(response.body)
      assert_equal false, body["ok"]
    end

    private
      def grant_teller_permissions(user, branch, workstation)
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

      def grant_supervisor_permissions(user, branch, workstation)
        [ "approvals.override.execute" ].each do |permission_key|
          permission = Permission.find_or_create_by!(key: permission_key) do |record|
            record.description = permission_key.humanize
          end

          role = Role.find_or_create_by!(key: "supervisor") do |record|
            record.name = "Supervisor"
          end

          RolePermission.find_or_create_by!(role: role, permission: permission)
          UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: workstation)
        end
      end
  end
end
