# frozen_string_literal: true

require "test_helper"

module Csr
  class PartiesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @branch = Branch.create!(code: "C01", name: "CSR Branch")
      grant_csr_access(@user, branch: @branch)
      sign_in_as(@user)
      set_branch_context(@branch.id)
    end

    test "index shows parties" do
      party = Party.create!(party_kind: "individual", relationship_kind: "customer")
      party.create_party_individual!(first_name: "CSR", last_name: "Test")

      get csr_parties_path

      assert_response :success
      assert_select "h2", "Parties"
    end

    test "show displays party" do
      party = Party.create!(party_kind: "individual", relationship_kind: "customer")
      party.create_party_individual!(first_name: "Show", last_name: "Me")

      get csr_party_path(party)

      assert_response :success
      assert_select "h1", /Show Me/
    end

    test "search returns parties as json" do
      party = Party.create!(party_kind: "individual", relationship_kind: "customer")
      party.create_party_individual!(first_name: "CSR", last_name: "Search")

      get search_csr_parties_path, params: { q: "CSR" }

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal 1, body.size
      assert_equal "CSR Search", body[0]["display_name"]
      assert_equal "customer", body[0]["relationship_kind"]
    end

    private

      def set_branch_context(branch_id)
        cookie_jar = ActionDispatch::TestRequest.create.cookie_jar
        cookie_jar.signed[:current_branch_id] = branch_id
        cookies["current_branch_id"] = cookie_jar["current_branch_id"]
      end

      def grant_csr_access(user, branch: nil)
        permission = Permission.find_or_create_by!(key: "csr.dashboard.view") do |record|
          record.description = "Access CSR workspace"
        end

        role = Role.find_or_create_by!(key: "csr_test") do |record|
          record.name = "CSR Test"
        end

        RolePermission.find_or_create_by!(role: role, permission: permission)
        UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: nil)
      end
  end
end
