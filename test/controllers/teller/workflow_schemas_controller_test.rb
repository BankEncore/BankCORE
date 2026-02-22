require "test_helper"

module Teller
  class WorkflowSchemasControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = User.take
      @branch = Branch.create!(code: "951", name: "Workflow Schema Branch")
      @workstation = Workstation.create!(branch: @branch, code: "WS1", name: "Workflow Schema WS")
    end

    test "requires authentication" do
      get teller_workflow_schema_path

      assert_redirected_to new_session_path
    end

    test "denies access without posting permission" do
      grant_dashboard_only(@user, @branch, @workstation)
      sign_in_as(@user)
      patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }

      get teller_workflow_schema_path

      assert_redirected_to root_path
    end

    test "returns workflow schema json with posting permission" do
      grant_posting_access(@user, @branch, @workstation)
      sign_in_as(@user)
      patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }

      get teller_workflow_schema_path

      assert_response :success
      body = JSON.parse(response.body)

      assert body.key?("workflows")
      assert_equal "Deposit", body.dig("workflows", "deposit", "label")
      assert_includes body.dig("workflows", "transfer", "required_fields"), "counterparty_account_reference"
      assert_includes body.dig("workflows", "draft", "funding_modes"), "cash"
      assert_includes body.dig("workflows", "deposit", "ui_sections"), "checks"
      assert_includes body.dig("workflows", "vault_transfer", "ui_sections"), "vault_transfer"
      assert_equal "deposit", body.dig("workflows", "deposit", "entry_profile")
      assert_equal "check_cashing", body.dig("workflows", "check_cashing", "entry_profile")
      assert_equal "cash_plus_checks", body.dig("workflows", "deposit", "effective_amount_source")
      assert_equal "check_cashing_net_payout", body.dig("workflows", "check_cashing", "amount_input_mode")
      assert_equal "vault_directional", body.dig("workflows", "vault_transfer", "cash_impact_profile")
      assert_equal true, body.dig("workflows", "transfer", "requires_counterparty_account")
      assert_equal "draft_cash_only", body.dig("workflows", "draft", "cash_account_policy")
      assert_equal true, body.dig("workflows", "check_cashing", "requires_settlement_account")
    end

    private
      def grant_dashboard_only(user, branch, workstation)
        assign_permissions(user, branch, workstation, [ "teller.dashboard.view" ], role_key: "teller_dashboard_only")
      end

      def grant_posting_access(user, branch, workstation)
        assign_permissions(user, branch, workstation, [ "teller.dashboard.view", "transactions.deposit.create", "sessions.open" ], role_key: "teller_posting_access")
      end

      def assign_permissions(user, branch, workstation, permission_keys, role_key:)
        role = Role.find_or_create_by!(key: role_key) do |record|
          record.name = "Teller"
        end

        permission_keys.each do |permission_key|
          permission = Permission.find_or_create_by!(key: permission_key) do |record|
            record.description = permission_key.humanize
          end

          RolePermission.find_or_create_by!(role: role, permission: permission)
        end

        UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: workstation)
      end
  end
end
