# frozen_string_literal: true

require "test_helper"

module Teller
  module Parts
    class CheckCashingsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = User.take
        @branch = Branch.create!(code: "PCC886", name: "Parts Check Cashing Branch")
        @workstation = Workstation.create!(branch: @branch, code: "PCC1", name: "Parts CC WS")
        @drawer = CashLocation.create!(
          branch: @branch,
          code: "PCCD1",
          name: "Parts CC Drawer",
          location_type: "drawer"
        )

        grant_permissions(@user, @branch, @workstation)
        sign_in_as(@user)
        patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }
        post teller_teller_session_path, params: { opening_cash_cents: 10_000, cash_location_id: @drawer.id }
        @party = Party.where(party_kind: "individual").first ||
          Party.create!(party_kind: "individual", relationship_kind: "customer", display_name: "Parts CC Party", is_active: true)
      end

      test "get new renders Parts check cashing page" do
        get new_teller_parts_check_cashing_path
        assert_response :success
        assert_select "h1, h2, .card-title", /Check Cashing \(Parts\)/
      end

      test "create posts via PartBuilder" do
        post teller_parts_check_cashings_path, params: {
          request_id: "parts-cc-1",
          transaction_type: "check_cashing",
          amount_cents: 5_000,
          fee_cents: 100,
          party_id: @party.id,
          cash_account_reference: "cash:#{@drawer.code}",
          fee_income_account_reference: "income:check_cashing_fee",
          check_items: [ {
            routing: "021",
            account: "123",
            number: "100",
            account_reference: "check:021:123:100",
            amount_cents: 5_000
          } ]
        }

        assert_response :success
        json = response.parsed_body
        assert json["ok"]
        transaction = TellerTransaction.find_by!(request_id: "parts-cc-1")
        assert_equal "check_cashing", transaction.transaction_type
      end

      private
        def grant_permissions(user, branch, workstation)
          %w[teller.dashboard.view transactions.deposit.create transactions.check_cashing.create transactions.vault_transfer.create sessions.open].each do |key|
            permission = Permission.find_or_create_by!(key: key) { |r| r.description = key.humanize }
            role = Role.find_or_create_by!(key: "teller") { |r| r.name = "Teller" }
            RolePermission.find_or_create_by!(role: role, permission: permission)
            UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: workstation)
          end
        end
    end
  end
end
