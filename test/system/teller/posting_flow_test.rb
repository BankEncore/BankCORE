require "application_system_test_case"

module Teller
  class PostingFlowTest < ApplicationSystemTestCase
    setup do
      skip "Set RUN_SYSTEM_TESTS=1 and ensure Chrome/ChromeDriver is installed to run" unless ENV["RUN_SYSTEM_TESTS"]
      @user = users(:one)
      @branch = Branch.create!(code: "SYS1", name: "System Test Branch")
      @workstation = Workstation.create!(branch: @branch, code: "SYSWS1", name: "System Test WS")
      @drawer = CashLocation.create!(
        branch: @branch,
        code: "SYSD1",
        name: "System Test Drawer",
        location_type: "drawer"
      )
      grant_posting_access(@user, @branch, @workstation)
    end

    test "deposit with currency-masked cash amount submits correct cents" do
      sign_in_via_ui
      set_teller_context
      open_teller_session_and_assign_drawer

      visit teller_deposit_transaction_path

      fill_in "Primary Account", with: "acct:deposit"
      fill_in "Cash Amount", with: "100"
      click_button "Post Transaction"

      assert_posted_amount_cents 10_000
    end

    test "deposit with decimal currency display submits correct cents" do
      sign_in_via_ui
      set_teller_context
      open_teller_session_and_assign_drawer

      visit teller_deposit_transaction_path

      fill_in "Primary Account", with: "acct:deposit"
      fill_in "Cash Amount", with: "100.50"
      click_button "Post Transaction"

      assert_posted_amount_cents 10_050
    end

    test "reset form clears currency display and next post works" do
      sign_in_via_ui
      set_teller_context
      open_teller_session_and_assign_drawer

      visit teller_deposit_transaction_path

      fill_in "Primary Account", with: "acct:deposit"
      fill_in "Cash Amount", with: "50"
      click_button "Cancel"
      assert_field "Cash Amount", with: "$0.00"

      fill_in "Primary Account", with: "acct:deposit-two"
      fill_in "Cash Amount", with: "25"
      click_button "Post Transaction"

      assert_posted_amount_cents 2_500
    end

    test "deposit fixed-flow page has required fields and blocks post when missing" do
      sign_in_via_ui
      set_teller_context
      open_teller_session_and_assign_drawer

      visit teller_deposit_transaction_path

      assert page.has_content?("Primary Account"), "Deposit should show primary account field"
      assert page.has_content?("Cash Amount"), "Deposit should show cash amount field"
      assert post_button_disabled?, "Post should be blocked when required fields are empty"
    end

    test "withdrawal fixed-flow page has required fields and blocks post when missing" do
      sign_in_via_ui
      set_teller_context
      open_teller_session_and_assign_drawer

      visit teller_withdrawal_transaction_path

      assert page.has_content?("Primary Account"), "Withdrawal should show primary account field"
      assert page.has_content?("Cash Amount"), "Withdrawal should show cash amount field"
      assert post_button_disabled?, "Post should be blocked when required fields are empty"
    end

    test "transfer fixed-flow page has required fields and blocks post when missing" do
      sign_in_via_ui
      set_teller_context
      open_teller_session_and_assign_drawer

      visit teller_transfer_transaction_path

      assert page.has_content?("Primary Account"), "Transfer should show primary account field"
      assert page.has_content?("Counterparty Account Reference"), "Transfer should show counterparty field"
      assert page.has_content?("Cash Amount"), "Transfer should show amount field"
      assert post_button_disabled?, "Post should be blocked when required fields are empty"
    end

    test "check cashing fixed-flow page has required fields and blocks post when missing" do
      sign_in_via_ui
      set_teller_context
      open_teller_session_and_assign_drawer

      visit teller_check_cashing_transaction_path

      assert page.has_content?("Check Amount"), "Check cashing should show check amount field"
      assert page.has_content?("Settlement Account Reference"), "Check cashing should show settlement account field"
      assert page.has_content?("ID Type"), "Check cashing should show ID type field"
      assert page.has_content?("ID Number"), "Check cashing should show ID number field"
      assert post_button_disabled?, "Post should be blocked when required fields are empty"
    end

    test "draft fixed-flow page has required fields and blocks post when missing" do
      sign_in_via_ui
      set_teller_context
      open_teller_session_and_assign_drawer

      visit teller_draft_transaction_path

      assert page.has_content?("Funding Source"), "Draft should show funding source field"
      assert page.has_content?("Draft Amount"), "Draft should show draft amount field"
      assert page.has_content?("Payee"), "Draft should show payee field"
      assert page.has_content?("Instrument Number"), "Draft should show instrument number field"
      assert post_button_disabled?, "Post should be blocked when required fields are empty"
    end

    test "vault transfer fixed-flow page has required fields and blocks post when missing" do
      sign_in_via_ui
      set_teller_context
      open_teller_session_and_assign_drawer

      visit teller_vault_transfer_transaction_path

      assert page.has_content?("Direction"), "Vault transfer should show direction field"
      assert page.has_content?("Reason Code"), "Vault transfer should show reason code field"
      assert post_button_disabled?, "Post should be blocked when required fields are empty"
    end

    private

      def sign_in_via_ui
        visit new_session_path
        fill_in "Email address", with: @user.email_address
        fill_in "Password", with: "password"
        click_button "Sign in"
      end

      def set_teller_context
        visit teller_context_path
        select @branch.name, from: "Branch"
        select @workstation.name, from: "Workstation"
        click_button "Update Context"
      end

      def open_teller_session_and_assign_drawer
        visit new_teller_teller_session_path
        select @drawer.name, from: "Drawer"
        fill_in "Opening cash", with: "50"
        click_button "Open Teller Session"
      end

      def assert_posted_amount_cents(expected_cents)
        batch = PostingBatch.order(created_at: :desc).first
        assert batch, "Expected a posting batch to be created"
        tx = batch.teller_transaction
        assert tx, "Expected a teller transaction"
        assert_equal expected_cents, tx.amount_cents, "Expected amount_cents to match"
      end

      def post_button_disabled?
        button = page.find(:button, "Post Transaction", match: :first)
        button.disabled?
      end

      def grant_posting_access(user, branch, workstation)
        %w[teller.dashboard.view transactions.deposit.create sessions.open].each do |permission_key|
          permission = Permission.find_or_create_by!(key: permission_key) do |record|
            record.description = permission_key.humanize
          end
          role = Role.find_or_create_by!(key: "teller") { |record| record.name = "Teller" }
          RolePermission.find_or_create_by!(role: role, permission: permission)
          UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: workstation)
        end
      end
  end
end
