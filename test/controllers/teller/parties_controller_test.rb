# frozen_string_literal: true

require "test_helper"

module Teller
  class PartiesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @branch = Branch.create!(code: "P01", name: "Parties Branch")
      @workstation = Workstation.create!(branch: @branch, code: "W01", name: "Workstation 01")
      grant_teller_dashboard_access(@user, branch: @branch, workstation: @workstation)
      sign_in_as(@user)
      set_signed_context(@branch.id, @workstation.id)
    end

    test "requires authentication" do
      sign_out
      get teller_parties_path
      assert_redirected_to new_session_path
    end

    test "index shows parties" do
      party = Party.create!(party_kind: "individual", relationship_kind: "customer")
      party.create_party_individual!(first_name: "Test", last_name: "User")

      get teller_parties_path

      assert_response :success
      assert_select "h2", "Parties"
    end

    test "new renders form" do
      get new_teller_party_path

      assert_response :success
      assert_select "form[action='#{teller_parties_path}']"
    end

    test "create party with individual" do
      assert_difference("Party.count", 1) do
        assert_difference("PartyIndividual.count", 1) do
          post teller_parties_path, params: {
            party: {
              party_kind: "individual",
              relationship_kind: "customer",
              first_name: "New",
              last_name: "Customer"
            }
          }
        end
      end

      assert_redirected_to teller_party_path(Party.last)
      assert_equal "New Customer", Party.last.display_name
    end

    test "create party with organization" do
      assert_difference("Party.count", 1) do
        assert_difference("PartyOrganization.count", 1) do
          post teller_parties_path, params: {
            party: {
              party_kind: "organization",
              relationship_kind: "customer",
              legal_name: "New Corp",
              dba_name: "NewCo"
            }
          }
        end
      end

      assert_redirected_to teller_party_path(Party.last)
      assert_equal "New Corp", Party.last.display_name
    end

    test "show displays party" do
      party = Party.create!(party_kind: "individual", relationship_kind: "customer")
      party.create_party_individual!(first_name: "Show", last_name: "Me")

      get teller_party_path(party)

      assert_response :success
      assert_select "h2", /Show Me/
    end

    test "search returns parties with display_name relationship address phone" do
      party = Party.create!(
        party_kind: "individual",
        relationship_kind: "customer",
        street_address: "123 Main St",
        city: "Springfield",
        state: "IL",
        zip_code: "62701",
        phone: "555-123-4567"
      )
      party.create_party_individual!(first_name: "Search", last_name: "Test")

      get search_teller_parties_path, params: { q: "Search" }

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal 1, body.size
      assert_equal "Search Test", body[0]["display_name"]
      assert_equal "customer", body[0]["relationship_kind"]
      assert_includes body[0]["address"], "123 Main St"
      assert_equal "555-123-4567", body[0]["phone"]
    end

    test "accounts returns party accounts as json" do
      party = Party.create!(party_kind: "individual", relationship_kind: "customer")
      party.create_party_individual!(first_name: "Acct", last_name: "Owner")
      account = Account.create!(
        branch: @branch,
        account_number: "9000000000009001",
        account_type: "checking",
        status: "open",
        opened_on: Date.current
      )
      AccountOwner.create!(account: account, party: party, is_primary: true)

      get accounts_teller_party_path(party)

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal 1, body.size
      assert_equal account.account_number, body[0]["account_number"]
      assert_equal "checking", body[0]["account_type"]
    end

    private

      def set_signed_context(branch_id, workstation_id)
        ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
          cookie_jar.signed[:current_branch_id] = branch_id
          cookie_jar.signed[:current_workstation_id] = workstation_id
          cookies["current_branch_id"] = cookie_jar["current_branch_id"]
          cookies["current_workstation_id"] = cookie_jar["current_workstation_id"]
        end
      end

      def grant_teller_dashboard_access(user, branch: nil, workstation: nil)
        permission = Permission.find_or_create_by!(key: "teller.dashboard.view") do |record|
          record.description = "Access teller dashboard"
        end

        role = Role.find_or_create_by!(key: "teller") do |record|
          record.name = "Teller"
        end

        RolePermission.find_or_create_by!(role: role, permission: permission)
        UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: workstation)
      end
  end
end
