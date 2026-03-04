# frozen_string_literal: true

require "test_helper"

module Admin
  class TransactionMiscReceiptDefaultsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @type = MiscReceiptType.create!(
        code: "admin_tmrd_test",
        label: "Admin Test Fee",
        income_account_reference: "income:admin_tmrd",
        default_amount_cents: 500,
        memo_required: false,
        display_order: 0,
        is_active: true
      )
    end

    test "index requires authentication" do
      get admin_transaction_misc_receipt_defaults_path
      assert_redirected_to new_session_path
    end

    test "index shows linked fees for admin user" do
      user = User.take
      grant_administration_access(user)
      sign_in_as(user)

      TransactionMiscReceiptDefault.create!(
        misc_receipt_type: @type,
        transaction_type: "deposit",
        override_policy: "teller_override",
        display_order: 0
      )

      get admin_transaction_misc_receipt_defaults_path

      assert_response :success
      assert_select "h2", "Linked Fees"
      assert_select "td", "Deposit"
      assert_select "td", "Admin Test Fee"
    end

    test "create adds new linked fee" do
      user = User.take
      grant_administration_access(user)
      sign_in_as(user)

      assert_difference "TransactionMiscReceiptDefault.count", 1 do
        post admin_transaction_misc_receipt_defaults_path, params: {
          transaction_misc_receipt_default: {
            transaction_type: "withdrawal",
            misc_receipt_type_id: @type.id,
            display_order: 0,
            mandatory: false,
            override_policy: "supervisor_override",
            default_amount_cents: 250
          }
        }
      end

      assert_redirected_to admin_transaction_misc_receipt_defaults_path
      follow_redirect!
      assert_select "div", /successfully created/i

      default = TransactionMiscReceiptDefault.find_by!(transaction_type: "withdrawal", misc_receipt_type_id: @type.id)
      assert_equal 250, default.default_amount_cents
      assert_equal "supervisor_override", default.override_policy
    end

    test "update modifies linked fee" do
      user = User.take
      grant_administration_access(user)
      sign_in_as(user)

      default = TransactionMiscReceiptDefault.create!(
        misc_receipt_type: @type,
        transaction_type: "draft",
        override_policy: "teller_override",
        default_amount_cents: 100,
        display_order: 0
      )

      patch admin_transaction_misc_receipt_default_path(default), params: {
        transaction_misc_receipt_default: {
          override_policy: "fixed",
          default_amount_cents: 300
        }
      }

      assert_redirected_to admin_transaction_misc_receipt_defaults_path
      default.reload
      assert_equal "fixed", default.override_policy
      assert_equal 300, default.default_amount_cents
    end

    test "destroy removes linked fee" do
      user = User.take
      grant_administration_access(user)
      sign_in_as(user)

      default = TransactionMiscReceiptDefault.create!(
        misc_receipt_type: @type,
        transaction_type: "transfer",
        override_policy: "teller_override",
        display_order: 0
      )

      assert_difference "TransactionMiscReceiptDefault.count", -1 do
        delete admin_transaction_misc_receipt_default_path(default)
      end

      assert_redirected_to admin_transaction_misc_receipt_defaults_path
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
