require "test_helper"

module Teller
  class TransactionSearchesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = User.take
      @branch = Branch.create!(code: "711", name: "Search Branch")
      @workstation = Workstation.create!(branch: @branch, code: "SR1", name: "Search WS")
      @drawer = CashLocation.create!(
        branch: @branch,
        code: "SDR1",
        name: "Search Drawer",
        location_type: "drawer"
      )
      @party = Party.create!(party_kind: "individual", relationship_kind: "customer", display_name: "Jane Doe", is_active: true)
      @party.create_party_individual!(first_name: "Jane", last_name: "Doe")
      @account = Account.create!(
        branch: @branch,
        account_number: "7000000000007001",
        account_type: "checking",
        status: "open",
        opened_on: Date.current
      )
      AccountOwner.create!(account: @account, party: @party, is_primary: true)

      grant_permissions(@user, @branch, @workstation)
      sign_in_as(@user)
      patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }
      post teller_teller_session_path, params: { opening_cash_cents: 10_000, cash_location_id: @drawer.id }
    end

    test "returns parties and accounts for search query" do
      get teller_transaction_search_path, params: { q: "Jane" }

      assert_response :success
      body = JSON.parse(response.body)
      assert body.key?("parties")
      assert body.key?("accounts")
      assert body["parties"].any? { |p| p["display_name"].include?("Jane") }
      assert body["accounts"].any? { |a| a["account_number"] == @account.account_number }
    end

    test "returns empty accounts when query blank" do
      get teller_transaction_search_path, params: { q: "" }

      assert_response :success
      body = JSON.parse(response.body)
      assert body["parties"].is_a?(Array)
      assert_equal [], body["accounts"]
    end

    private
      def grant_permissions(user, branch, workstation)
        [ "teller.dashboard.view", "transactions.deposit.create", "sessions.open" ].each do |permission_key|
          permission = Permission.find_or_create_by!(key: permission_key) { |r| r.description = permission_key.humanize }
          role = Role.find_or_create_by!(key: "teller") { |r| r.name = "Teller" }
          RolePermission.find_or_create_by!(role: role, permission: permission)
          UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: workstation)
        end
      end
  end
end
