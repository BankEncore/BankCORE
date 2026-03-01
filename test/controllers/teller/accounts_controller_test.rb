# frozen_string_literal: true

require "test_helper"

module Teller
  class AccountsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @branch = Branch.create!(code: "A01", name: "Accounts Branch")
      @workstation = Workstation.create!(branch: @branch, code: "W01", name: "Workstation 01")
      @party = Party.create!(party_kind: "individual", relationship_kind: "customer")
      @party.create_party_individual!(first_name: "Account", last_name: "Owner")
      grant_teller_dashboard_access(@user, branch: @branch, workstation: @workstation)
      sign_in_as(@user)
      set_signed_context(@branch.id, @workstation.id)
    end

    test "requires authentication" do
      sign_out
      get teller_accounts_path
      assert_redirected_to new_session_path
    end

    test "index shows accounts" do
      account = Account.create!(account_number: "1234567890123456", account_type: "checking", branch: @branch, status: "open", opened_on: Date.current, last_activity_at: Time.current)
      AccountOwner.create!(account: account, party: @party, is_primary: true)

      get teller_accounts_path

      assert_response :success
      assert_select "h2", "Accounts"
    end

    test "new redirects to context when no branch" do
      sign_in_as(@user)
      cookies.delete("current_branch_id")
      cookies.delete("current_workstation_id")

      get new_teller_account_path

      assert_redirected_to teller_context_path
    end

    test "new renders form when branch set" do
      get new_teller_account_path(branch_id: @branch.id)

      assert_response :success
      assert_select "form[action='#{teller_accounts_path}']"
    end

    test "create account with owner" do
      assert_difference("Account.count", 1) do
        assert_difference("AccountOwner.count", 1) do
          post teller_accounts_path, params: {
            account: {
              account_number: "9999999999999999",
              account_type: "checking",
              branch_id: @branch.id,
              opened_on: Date.current.strftime("%Y-%m-%d"),
              status: "open",
              primary_party_id: @party.id
            }
          }
        end
      end

      assert_redirected_to teller_account_path(Account.last)
      assert Account.last.account_owners.where(party: @party, is_primary: true).exists?
    end

    test "show displays account" do
      account = Account.create!(account_number: "1111111111111111", account_type: "savings", branch: @branch, status: "open", opened_on: Date.current, last_activity_at: Time.current)
      AccountOwner.create!(account: account, party: @party, is_primary: true)

      get teller_account_path(account)

      assert_response :success
      assert_select "h2", /1111/  # Account number is masked; last 4 digits visible
    end

    test "edit renders form" do
      account = Account.create!(account_number: "2222222222222222", account_type: "checking", branch: @branch, status: "open", opened_on: Date.current, last_activity_at: Time.current)
      AccountOwner.create!(account: account, party: @party, is_primary: true)

      get edit_teller_account_path(account)

      assert_response :success
      assert_select "form[action='#{teller_account_path(account)}']"
    end

    test "update changes account" do
      account = Account.create!(account_number: "3333333333333333", account_type: "checking", branch: @branch, status: "open", opened_on: Date.current, last_activity_at: Time.current)
      AccountOwner.create!(account: account, party: @party, is_primary: true)

      patch teller_account_path(account), params: {
        account: { account_type: "savings", status: "restricted", opened_on: Date.current, closed_on: nil }
      }

      assert_redirected_to teller_account_path(account)
      account.reload
      assert_equal "savings", account.account_type
      assert_equal "restricted", account.status
    end

    test "related_parties returns related parties for account as json" do
      account = Account.create!(account_number: "6666666666666666", account_type: "checking", branch: @branch, status: "open", opened_on: Date.current, last_activity_at: Time.current)
      AccountOwner.create!(account: account, party: @party, is_primary: true)

      get related_parties_teller_account_path(account)

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal 1, body.size
      assert_equal @party.id, body[0]["id"]
      assert_includes body[0]["display_name"], "Account"
      assert_equal "Primary Owner", body[0]["relationship_type"]
    end

    test "related_parties requires authentication" do
      account = Account.create!(account_number: "7777777777777777", account_type: "checking", branch: @branch, status: "open", opened_on: Date.current, last_activity_at: Time.current)
      AccountOwner.create!(account: account, party: @party, is_primary: true)
      sign_out

      get related_parties_teller_account_path(account)

      assert_redirected_to new_session_path
    end

    test "related_parties returns empty when account has no owners" do
      account = Account.create!(account_number: "5555555555555555", account_type: "checking", branch: @branch, status: "open", opened_on: Date.current, last_activity_at: Time.current)

      get related_parties_teller_account_path(account)

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal [], body
    end

    test "update can change account_number" do
      account = Account.create!(account_number: "4444444444444444", account_type: "checking", branch: @branch, status: "open", opened_on: Date.current, last_activity_at: Time.current)
      AccountOwner.create!(account: account, party: @party, is_primary: true)

      patch teller_account_path(account), params: {
        account: { account_number: "5555555555555555", account_type: "checking", status: "open", opened_on: Date.current, closed_on: nil }
      }

      assert_redirected_to teller_account_path(account)
      account.reload
      assert_equal "5555555555555555", account.account_number
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
