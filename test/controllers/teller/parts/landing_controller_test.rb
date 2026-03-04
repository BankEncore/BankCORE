# frozen_string_literal: true

require "test_helper"

module Teller
  module Parts
    class LandingControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = User.take
        @branch = Branch.create!(code: "PL883", name: "Parts Landing Branch")
        @workstation = Workstation.create!(branch: @branch, code: "PL1", name: "Parts Landing WS")
        @drawer = CashLocation.create!(
          branch: @branch,
          code: "PLD1",
          name: "Parts Landing Drawer",
          location_type: "drawer"
        )
        grant_permissions(@user, @branch, @workstation)
        sign_in_as(@user)
        patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }
        post teller_teller_session_path, params: { opening_cash_cents: 10_000, cash_location_id: @drawer.id }
      end

      test "get index renders Parts landing page with flow links" do
        get teller_parts_root_path
        assert_response :success
        assert_select "h1", /Parts \(test\)/
        assert_select "a[href=?]", new_teller_parts_deposit_path, text: /Deposit/
        assert_select "a[href=?]", new_teller_parts_vault_transfer_path, text: /Vault Transfer/
      end

      private
        def grant_permissions(user, branch, workstation)
          %w[teller.dashboard.view transactions.deposit.create transactions.vault_transfer.create sessions.open].each do |key|
            permission = Permission.find_or_create_by!(key: key) { |r| r.description = key.humanize }
            role = Role.find_or_create_by!(key: "teller") { |r| r.name = "Teller" }
            RolePermission.find_or_create_by!(role: role, permission: permission)
            UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: workstation)
          end
        end
    end
  end
end
