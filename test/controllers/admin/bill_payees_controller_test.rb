# frozen_string_literal: true

require "test_helper"

module Admin
  class BillPayeesControllerTest < ActionDispatch::IntegrationTest
    test "index requires authentication" do
      get admin_bill_payees_path
      assert_redirected_to new_session_path
    end

    test "index shows bill payees for admin user" do
      user = User.take
      grant_administration_access(user)
      sign_in_as(user)

      BillPayee.create!(code: "ADMIN_BP", name: "Admin Test Payee", liability_account_reference: "liability:ADMIN_BP", memo_required: false, is_active: true)

      get admin_bill_payees_path

      assert_response :success
      assert_select "h2", "Bill Payees"
      assert_select "td", "ADMIN_BP"
      assert_select "td", "Admin Test Payee"
    end

    test "create adds new bill payee" do
      user = User.take
      grant_administration_access(user)
      sign_in_as(user)

      assert_difference "BillPayee.count", 1 do
        post admin_bill_payees_path, params: {
          bill_payee: {
            code: "NEW_BP",
            name: "New Bill Payee",
            liability_account_reference: "liability:NEW_BP",
            default_fee_amount_cents: 100,
            memo_required: false,
            is_active: true,
            display_order: 0
          }
        }
      end

      assert_redirected_to admin_bill_payees_path
      follow_redirect!
      assert_select "div", /successfully created/i

      payee = BillPayee.find_by!(code: "NEW_BP")
      assert_equal "New Bill Payee", payee.name
      assert_equal 100, payee.default_fee_amount_cents
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
