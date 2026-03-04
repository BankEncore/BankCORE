# frozen_string_literal: true

require "test_helper"

module Teller
  module Parts
    class VaultTransfersControllerTest < ActionDispatch::IntegrationTest
      setup do
        ensure_cash_denominations
        @user = User.take
        @branch = Branch.create!(code: "PV882", name: "Parts Vault Branch")
        @workstation = Workstation.create!(branch: @branch, code: "PV1", name: "Parts Vault WS")
        @drawer = CashLocation.create!(
          branch: @branch,
          code: "PVD1",
          name: "Parts Vault Drawer",
          location_type: "drawer"
        )
        @vault = CashLocation.create!(
          branch: @branch,
          code: "PVV1",
          name: "Parts Vault",
          location_type: "vault"
        )

        grant_permissions(@user, @branch, @workstation)
        sign_in_as(@user)
        patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }
        post teller_teller_session_path, params: { opening_cash_cents: 10_000, cash_location_id: @drawer.id }
      end

      test "get new renders Parts vault transfer page" do
        get new_teller_parts_vault_transfer_path
        assert_response :success
        assert_select "h1, h2, .card-title", /Vault Transfer \(Parts\)/
      end

      private
        def ensure_cash_denominations
          return if CashDenomination.enabled.exists?

          [ 2_000, 1_000, 500 ].each_with_index do |face_value, i|
            CashDenomination.create!(
              code: "USD_BILL_#{face_value}_parts_vt",
              kind: "bill",
              face_value_cents: face_value,
              display_label: "$#{face_value / 100}",
              sort_order: 30 + i,
              enabled: true
            )
          end
        end

        def denomination_lines_for(amount_cents)
          denom = CashDenomination.enabled.to_a.find { |d| amount_cents % d.unit_value_cents == 0 }
          return [] if denom.blank?

          qty = amount_cents / denom.unit_value_cents
          [ { cash_denomination_id: denom.id, qty: qty, amount_cents: amount_cents } ]
        end

        def grant_permissions(user, branch, workstation)
          %w[teller.dashboard.view transactions.deposit.create transactions.vault_transfer.create sessions.open].each do |key|
            permission = Permission.find_or_create_by!(key: key) { |r| r.description = key.humanize }
            role = Role.find_or_create_by!(key: "teller") { |r| r.name = "Teller" }
            RolePermission.find_or_create_by!(role: role, permission: permission)
            UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: workstation)
          end
        end

      test "create posts via PartBuilder" do
        post teller_parts_vault_transfers_path, params: {
          request_id: "parts-vt-1",
          transaction_type: "vault_transfer",
          amount_cents: 5_000,
          vault_transfer_direction: "drawer_to_vault",
          vault_transfer_source_cash_account_reference: "cash:#{@drawer.code}",
          vault_transfer_destination_cash_account_reference: "cash:#{@vault.code}",
          vault_transfer_reason_code: "excess_cash",
          denomination_lines: denomination_lines_for(5_000)
        }

        assert_response :success
        json = response.parsed_body
        assert json["ok"]
        transaction = TellerTransaction.find_by!(request_id: "parts-vt-1")
        assert_equal "vault_transfer", transaction.transaction_type
      end
    end
  end
end
