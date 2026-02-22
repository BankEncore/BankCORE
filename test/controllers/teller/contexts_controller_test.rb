require "test_helper"

module Teller
  class ContextsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = User.take
      @branch = Branch.create!(code: "201", name: "Context Branch")
      @workstation = Workstation.create!(branch: @branch, code: "CTX1", name: "Context WS")

      grant_permissions(@user, @branch, @workstation)
      sign_in_as(@user)
    end

    test "redirects teller routes to context workflow when context is missing" do
      get teller_root_path

      assert_redirected_to teller_context_path
    end

    test "allows teller dashboard when branch/workstation are present in signed cookies" do
      set_signed_cookie(:current_branch_id, @branch.id)
      set_signed_cookie(:current_workstation_id, @workstation.id)

      get teller_root_path

      assert_response :success
    end

    test "redirects back to attempted teller path after valid context update" do
      get teller_root_path
      assert_redirected_to teller_context_path

      patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }

      assert_redirected_to teller_root_path
    end

    test "requires workstation during context update" do
      patch teller_context_path, params: { branch_id: @branch.id }

      assert_redirected_to teller_context_path
      assert_equal "Please select a valid workstation.", flash[:alert]
    end

    test "shows workstation mapping payload for branch-driven selection" do
      second_branch = Branch.create!(code: "202", name: "Context Branch 2")
      second_workstation = Workstation.create!(branch: second_branch, code: "CTX2", name: "Context WS 2")

      get teller_context_path

      assert_response :success
      assert_includes response.body, "data-teller-context-workstations-by-branch-value"
      assert_includes response.body, @workstation.name
      assert_includes response.body, second_workstation.name
    end

    private
      def set_signed_cookie(key, value)
        ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
          cookie_jar.signed[key] = value
          cookies[key.to_s] = cookie_jar[key]
        end
      end

      def grant_permissions(user, branch, workstation)
        permission = Permission.find_or_create_by!(key: "teller.dashboard.view") do |record|
          record.description = "Teller Dashboard View"
        end

        role = Role.find_or_create_by!(key: "teller") do |record|
          record.name = "Teller"
        end

        RolePermission.find_or_create_by!(role: role, permission: permission)
        UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: workstation)
      end
  end
end
