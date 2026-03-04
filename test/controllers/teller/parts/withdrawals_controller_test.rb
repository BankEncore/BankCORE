# frozen_string_literal: true

require "test_helper"

module Teller
  module Parts
    class WithdrawalsControllerTest < ActionDispatch::IntegrationTest
      setup do
        ensure_cash_denominations
        @user = User.take
        @branch = Branch.create!(code: "PW884", name: "Parts Withdrawal Branch")
        @workstation = Workstation.create!(branch: @branch, code: "PW1", name: "Parts Withdrawal WS")
        @drawer = CashLocation.create!(
          branch: @branch,
          code: "PWD1",
          name: "Parts Withdrawal Drawer",
          location_type: "drawer"
        )
        Account.create!(
          account_number: "partswd",
          account_type: "checking",
          branch: @branch,
          status: "open",
          opened_on: Date.current,
          last_activity_at: Time.current
        ) unless Account.exists?(account_number: "partswd")

        grant_permissions(@user, @branch, @workstation)
        sign_in_as(@user)
        patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }
        post teller_teller_session_path, params: { opening_cash_cents: 10_000, cash_location_id: @drawer.id }
        @party = Party.where(party_kind: "individual").first ||
          Party.create!(party_kind: "individual", relationship_kind: "customer", display_name: "Parts Withdrawal Party", is_active: true)
      end

      test "get new renders Parts withdrawal page" do
        get new_teller_parts_withdrawal_path
        assert_response :success
        assert_select "h1, h2, .card-title", /Withdrawal \(Parts\)/
      end

      test "create posts via PartBuilder" do
        post teller_parts_withdrawals_path, params: {
          request_id: "parts-wd-1",
          transaction_type: "withdrawal",
          amount_cents: 3_000,
          fee_cents: 0,
          party_id: @party.id,
          primary_account_reference: "acct:partswd",
          cash_account_reference: "cash:#{@drawer.code}"
        }

        assert_response :success
        json = response.parsed_body
        assert json["ok"]
        transaction = TellerTransaction.find_by!(request_id: "parts-wd-1")
        assert_equal "withdrawal", transaction.transaction_type
      end

      private
        def ensure_cash_denominations
          return if CashDenomination.enabled.exists?

          [ 2_000, 1_000, 500 ].each_with_index do |face_value, i|
            CashDenomination.create!(
              code: "USD_BILL_#{face_value}_parts_wd",
              kind: "bill",
              face_value_cents: face_value,
              display_label: "$#{face_value / 100}",
              sort_order: 30 + i,
              enabled: true
            )
          end
        end

        def grant_permissions(user, branch, workstation)
          %w[teller.dashboard.view transactions.deposit.create transactions.withdrawal.create transactions.vault_transfer.create sessions.open].each do |key|
            permission = Permission.find_or_create_by!(key: key) { |r| r.description = key.humanize }
            role = Role.find_or_create_by!(key: "teller") { |r| r.name = "Teller" }
            RolePermission.find_or_create_by!(role: role, permission: permission)
            UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: workstation)
          end
        end
    end
  end
end
