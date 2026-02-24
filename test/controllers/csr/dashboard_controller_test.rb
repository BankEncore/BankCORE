# frozen_string_literal: true

require "test_helper"

module Csr
  class DashboardControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @branch = Branch.create!(code: "C01", name: "CSR Branch")
      grant_csr_access(@user, branch: @branch)
      sign_in_as(@user)
      set_branch_context(@branch.id)
    end

    test "requires authentication" do
      sign_out
      get csr_root_path
      assert_redirected_to new_session_path
    end

    test "redirects to context when branch not set" do
      cookies.delete("current_branch_id")

      get csr_root_path

      assert_redirected_to csr_context_path
    end

    test "index shows dashboard when branch set" do
      get csr_root_path

      assert_response :success
      assert_select "h2", "CSR Workspace"
    end

    private

      def set_branch_context(branch_id)
        cookie_jar = ActionDispatch::TestRequest.create.cookie_jar
        cookie_jar.signed[:current_branch_id] = branch_id
        cookies["current_branch_id"] = cookie_jar["current_branch_id"]
      end

      def grant_csr_access(user, branch: nil)
        permission = Permission.find_or_create_by!(key: "csr.dashboard.view") do |record|
          record.description = "Access CSR workspace"
        end

        role = Role.find_or_create_by!(key: "csr_test") do |record|
          record.name = "CSR Test"
        end

        RolePermission.find_or_create_by!(role: role, permission: permission)
        UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: nil)
      end
  end
end
