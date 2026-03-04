# frozen_string_literal: true

require "test_helper"

module Teller
  module Parts
    class TransfersControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = User.take
        @branch = Branch.create!(code: "PT885", name: "Parts Transfer Branch")
        @workstation = Workstation.create!(branch: @branch, code: "PT1", name: "Parts Transfer WS")
        @drawer = CashLocation.create!(
          branch: @branch,
          code: "PTD1",
          name: "Parts Transfer Drawer",
          location_type: "drawer"
        )
        %w[partsfrom partsto].each do |acct_num|
          next if Account.exists?(account_number: acct_num)

          Account.create!(
            account_number: acct_num,
            account_type: "checking",
            branch: @branch,
            status: "open",
            opened_on: Date.current,
            last_activity_at: Time.current
          )
        end

        grant_permissions(@user, @branch, @workstation)
        sign_in_as(@user)
        patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }
        post teller_teller_session_path, params: { opening_cash_cents: 5_000, cash_location_id: @drawer.id }
        @party = Party.where(party_kind: "individual").first ||
          Party.create!(party_kind: "individual", relationship_kind: "customer", display_name: "Parts Transfer Party", is_active: true)
      end

      test "get new renders Parts transfer page" do
        get new_teller_parts_transfer_path
        assert_response :success
        assert_select "h1, h2, .card-title", /Transfer \(Parts\)/
      end

      test "create posts via PartBuilder" do
        post teller_parts_transfers_path, params: {
          request_id: "parts-xfr-1",
          transaction_type: "transfer",
          amount_cents: 2_000,
          fee_cents: 0,
          party_id: @party.id,
          primary_account_reference: "acct:partsfrom",
          counterparty_account_reference: "acct:partsto",
          cash_account_reference: "cash:#{@drawer.code}"
        }

        assert_response :success
        json = response.parsed_body
        assert json["ok"]
        transaction = TellerTransaction.find_by!(request_id: "parts-xfr-1")
        assert_equal "transfer", transaction.transaction_type
      end

      private
        def grant_permissions(user, branch, workstation)
          %w[teller.dashboard.view transactions.deposit.create transactions.transfer.create transactions.vault_transfer.create sessions.open].each do |key|
            permission = Permission.find_or_create_by!(key: key) { |r| r.description = key.humanize }
            role = Role.find_or_create_by!(key: "teller") { |r| r.name = "Teller" }
            RolePermission.find_or_create_by!(role: role, permission: permission)
            UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: workstation)
          end
        end
    end
  end
end
