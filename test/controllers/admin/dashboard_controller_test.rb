# frozen_string_literal: true

require "test_helper"

module Admin
  class DashboardControllerTest < ActionDispatch::IntegrationTest
    test "requires authentication" do
      get admin_root_path
      assert_redirected_to new_session_path
    end

    test "denies access without administration permission" do
      user = User.take
      sign_in_as(user)

      get admin_root_path

      assert_redirected_to root_path
      follow_redirect!
      assert_select "div", /not authorized/i
    end

    test "shows dashboard for admin user" do
      user = User.take
      grant_administration_access(user)
      sign_in_as(user)

      get admin_root_path

      assert_response :success
      assert_select "h2", "Administration Workspace"
      assert_select "a[href='#{admin_branches_path}']", "Branches"
    end

    test "shows branches index for admin user" do
      user = User.take
      grant_administration_access(user)
      sign_in_as(user)

      get admin_branches_path

      assert_response :success
      assert_select "h2", "Branches"
    end

    test "assigns role to user" do
      user = User.take
      role = Role.find_or_create_by!(key: "teller") { |r| r.name = "Teller" }
      grant_administration_access(user)
      sign_in_as(user)

      assert_difference "user.user_roles.count", 1 do
        post admin_user_user_roles_path(user), params: { user_role: { role_id: role.id, branch_id: "", workstation_id: "" } }
      end

      assert_redirected_to admin_user_path(user)
      follow_redirect!
      assert_select "div", /Role was successfully assigned/i
    end

    private
      def grant_administration_access(user)
        permission = Permission.find_or_create_by!(key: "administration.workspace.view") do |record|
          record.description = "Access Administration workspace"
        end

        role = Role.find_or_create_by!(key: "admin") { |r| r.name = "Administrator" }
        RolePermission.find_or_create_by!(role: role, permission: permission)
        UserRole.find_or_create_by!(user: user, role: role, branch: nil, workstation: nil)
      end
  end
end
