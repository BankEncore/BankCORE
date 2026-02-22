require "test_helper"

module Teller
  class TransactionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = User.take
      @branch = Branch.create!(code: "501", name: "Validation Branch")
      @workstation = Workstation.create!(branch: @branch, code: "VW1", name: "Validation WS")
      @drawer = CashLocation.create!(
        branch: @branch,
        code: "VDR1",
        name: "Validation Drawer",
        location_type: "drawer"
      )

      grant_permissions(@user, @branch, @workstation)
      sign_in_as(@user)
      patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }
      post teller_teller_session_path, params: { opening_cash_cents: 10_000 }
      patch assign_drawer_teller_teller_session_path, params: { cash_location_id: @drawer.id }
    end

    test "validates a balanced deposit request" do
      post teller_validate_transaction_path, params: {
        request_id: "validate-1",
        transaction_type: "deposit",
        amount_cents: 20_000,
        primary_account_reference: "acct:customer",
        cash_account_reference: "cash:drawer"
      }

      assert_response :success
      body = JSON.parse(response.body)

      assert_equal true, body["ok"]
      assert_equal false, body["approval_required"]
      assert_equal 20_000, body.dig("totals", "debit_cents")
      assert_equal 20_000, body.dig("totals", "credit_cents")
      assert_equal 0, body.dig("totals", "imbalance_cents")
    end

    test "flags approval required for threshold amount" do
      post teller_validate_transaction_path, params: {
        request_id: "validate-2",
        transaction_type: "deposit",
        amount_cents: 150_000,
        primary_account_reference: "acct:customer",
        cash_account_reference: "cash:drawer"
      }

      assert_response :success
      body = JSON.parse(response.body)

      assert_equal true, body["ok"]
      assert_equal true, body["approval_required"]
      assert_match(/threshold/i, body["approval_reason"])
      assert_equal "amount_threshold", body["approval_policy_trigger"]
      assert_equal "deposit", body.dig("approval_policy_context", "transaction_type")
      assert_equal 150_000, body.dig("approval_policy_context", "amount_cents")
      assert_equal 100_000, body.dig("approval_policy_context", "threshold_cents")
    end

    test "validates balanced explicit split entries for deposit" do
      post teller_validate_transaction_path, params: {
        request_id: "validate-3",
        transaction_type: "deposit",
        amount_cents: 30_000,
        primary_account_reference: "acct:customer",
        cash_account_reference: "cash:drawer",
        entries: [
          { side: "debit", account_reference: "cash:drawer", amount_cents: 10_000 },
          { side: "debit", account_reference: "check:111000:222000:9001", amount_cents: 20_000 },
          { side: "credit", account_reference: "acct:customer", amount_cents: 30_000 }
        ]
      }

      assert_response :success
      body = JSON.parse(response.body)

      assert_equal true, body["ok"]
      assert_equal 30_000, body.dig("totals", "debit_cents")
      assert_equal 30_000, body.dig("totals", "credit_cents")
      assert_equal 0, body.dig("totals", "imbalance_cents")
    end

    test "validates draft payload requirements" do
      post teller_validate_transaction_path, params: {
        request_id: "validate-draft-1",
        transaction_type: "draft",
        amount_cents: 12_500,
        draft_funding_source: "account",
        draft_amount_cents: 12_000,
        draft_fee_cents: 500,
        draft_payee_name: "County Recorder",
        draft_instrument_number: "OD-9001",
        draft_liability_account_reference: "official_check:outstanding",
        primary_account_reference: "acct:customer"
      }

      assert_response :success
      body = JSON.parse(response.body)

      assert_equal true, body["ok"]
      assert_equal false, body["approval_required"]
      assert_equal 12_500, body.dig("totals", "amount_cents")
    end

    private
      def grant_permissions(user, branch, workstation)
        [ "teller.dashboard.view", "transactions.deposit.create", "sessions.open" ].each do |permission_key|
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
