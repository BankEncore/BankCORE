# frozen_string_literal: true

require "test_helper"

module Admin
  class UsersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = User.take
      grant_administration_access(@user)
      sign_in_as(@user)
    end

    test "creates user with new profile fields" do
      assert_difference "User.count", 1 do
        post admin_users_path, params: {
          user: {
            email_address: "newuser@example.com",
            teller_number: "N001",
            first_name: "New",
            last_name: "User",
            password: "password",
            password_confirmation: "password"
          }
        }
      end

      assert_redirected_to admin_user_path(User.find_by!(email_address: "newuser@example.com"))
      created = User.find_by!(email_address: "newuser@example.com")
      assert_equal "N001", created.teller_number
      assert_equal "New", created.first_name
      assert_equal "User", created.last_name
      assert_equal "New U", created.display_name
    end

    test "updates user with new profile fields" do
      target = User.create!(email_address: "update-target@example.com", password: "password")

      patch admin_user_path(target), params: {
        user: {
          email_address: "update-target@example.com",
          first_name: "Updated",
          last_name: "Name",
          teller_number: "U001"
        }
      }

      assert_redirected_to admin_user_path(target)
      target.reload
      assert_equal "Updated", target.first_name
      assert_equal "Name", target.last_name
      assert_equal "U001", target.teller_number
      assert_equal "Updated N", target.display_name
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
