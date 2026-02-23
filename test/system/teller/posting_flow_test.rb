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

      fill_in "Primary Account Reference", with: "acct:deposit"
      fill_in "Cash Amount", with: "100"
      click_button "Post Transaction"

      assert_posted_amount_cents 10_000
    end

    test "deposit with decimal currency display submits correct cents" do
      sign_in_via_ui
      set_teller_context
      open_teller_session_and_assign_drawer

      visit teller_deposit_transaction_path

      fill_in "Primary Account Reference", with: "acct:deposit"
      fill_in "Cash Amount", with: "100.50"
      click_button "Post Transaction"

      assert_posted_amount_cents 10_050
    end

    test "reset form clears currency display and next post works" do
      sign_in_via_ui
      set_teller_context
      open_teller_session_and_assign_drawer

      visit teller_deposit_transaction_path

      fill_in "Primary Account Reference", with: "acct:deposit"
      fill_in "Cash Amount", with: "50"
      click_button "Cancel"
      assert_field "Cash Amount", with: "$0.00"

      fill_in "Primary Account Reference", with: "acct:deposit-two"
      fill_in "Cash Amount", with: "25"
      click_button "Post Transaction"

      assert_posted_amount_cents 2_500
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
        fill_in "Opening cash (cents)", with: "5000"
        click_button "Open Teller Session"
        select @drawer.name, from: "Assign drawer"
        click_button "Assign Drawer"
      end

      def assert_posted_amount_cents(expected_cents)
        batch = PostingBatch.order(created_at: :desc).first
        assert batch, "Expected a posting batch to be created"
        tx = batch.teller_transaction
        assert tx, "Expected a teller transaction"
        assert_equal expected_cents, tx.amount_cents, "Expected amount_cents to match"
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
