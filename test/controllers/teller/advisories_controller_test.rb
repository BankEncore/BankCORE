# frozen_string_literal: true

require "test_helper"

module Teller
  class AdvisoriesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = User.take
      @branch = Branch.create!(code: "A99", name: "Advisories Branch")
      @workstation = Workstation.create!(branch: @branch, code: "W99", name: "Advisories WS")
      @party = Party.create!(party_kind: "individual", relationship_kind: "customer", display_name: "Advisory Party", is_active: true)
      @party.create_party_individual!(first_name: "Advisory", last_name: "Party")
      @account = Account.create!(
        account_number: "8888888888888888",
        account_type: "checking",
        branch: @branch,
        status: "open",
        opened_on: Date.current,
        last_activity_at: Time.current
      )
      AccountOwner.create!(account: @account, party: @party, is_primary: true)

      grant_permissions(@user, @branch, @workstation)
      sign_in_as(@user)
      patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }
      post teller_teller_session_path, params: { opening_cash_cents: 0, cash_location_id: CashLocation.create!(branch: @branch, code: "D99", name: "Drawer", location_type: "drawer").id }
    end

    test "for_entity returns advisories when account_reference has acct: prefix" do
      Advisory.create!(
        scope_type: "account",
        scope_id: @account.id.to_s,
        workspace_visibility: "teller",
        severity: :notice,
        title: "Test advisory",
        body: "For acct prefix test"
      )

      get teller_advisories_for_entity_path, params: { account_reference: "acct:#{@account.account_number}" }

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal true, body["ok"]
      assert_equal 1, body["advisories"].size
      assert_equal "Test advisory", body["advisories"][0]["title"]
      assert_equal "notice", body["advisories"][0]["severity"]
      assert body["record_path"].present?
      assert_includes body["record_path"], "advisories"
    end

    test "for_entity returns advisories when account_reference has no prefix" do
      Advisory.create!(
        scope_type: "account",
        scope_id: @account.id.to_s,
        workspace_visibility: "teller",
        severity: :notice,
        title: "Raw account ref advisory",
        body: nil
      )

      get teller_advisories_for_entity_path, params: { account_reference: @account.account_number }

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal true, body["ok"]
      assert_equal 1, body["advisories"].size
      assert_equal "Raw account ref advisory", body["advisories"][0]["title"]
    end

    private

      def grant_permissions(user, branch, workstation)
        [ "teller.dashboard.view", "advisories.view", "transactions.deposit.create", "sessions.open" ].each do |permission_key|
          permission = Permission.find_or_create_by!(key: permission_key) do |record|
            record.description = permission_key.humanize
          end

          role = Role.find_or_create_by!(key: "teller") do |record|
            record.name = "Teller"
          end

          RolePermission.find_or_create_by!(role: role, permission: permission)
          UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: workstation)
        end
      end
  end
end
