require "test_helper"

module Teller
  class AccountReferencesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = User.take
      @branch = Branch.create!(code: "611", name: "Account Ref Branch")
      @workstation = Workstation.create!(branch: @branch, code: "AR1", name: "Account Ref WS")
      @drawer = CashLocation.create!(
        branch: @branch,
        code: "ADR1",
        name: "Account Ref Drawer",
        location_type: "drawer"
      )

      grant_permissions(@user, @branch, @workstation)
      sign_in_as(@user)
      patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }
      post teller_teller_session_path, params: { opening_cash_cents: 10_000 }
      patch assign_drawer_teller_teller_session_path, params: { cash_location_id: @drawer.id }
    end

    test "returns account snapshot for known account reference" do
      post teller_posting_path, params: {
        request_id: "acct-ref-1",
        transaction_type: "deposit",
        amount_cents: 25_000,
        primary_account_reference: "acct:customer-001",
        cash_account_reference: "cash:#{@drawer.code}"
      }

      get teller_account_reference_path, params: { reference: "acct:customer-001" }

      assert_response :success
      body = JSON.parse(response.body)

      assert_equal true, body["ok"]
      assert_equal true, body["found"]
      assert_equal "Active", body["status"]
      assert_equal 25_000, body["ledger_balance_cents"]
      assert_equal 25_000, body["available_balance_cents"]
      assert_equal 0, body["total_debits_cents"]
      assert_equal 25_000, body["total_credits_cents"]
      assert_not_nil body["last_posted_at"]
    end

    test "returns zeroed snapshot for unknown account reference" do
      get teller_account_reference_path, params: { reference: "acct:unknown" }

      assert_response :success
      body = JSON.parse(response.body)

      assert_equal true, body["ok"]
      assert_equal false, body["found"]
      assert_equal "No activity", body["status"]
      assert_equal 0, body["ledger_balance_cents"]
      assert_equal 0, body["available_balance_cents"]
      assert_equal 0, body["total_debits_cents"]
      assert_equal 0, body["total_credits_cents"]
      assert_nil body["last_posted_at"]
    end

    test "returns unprocessable entity when reference is blank" do
      get teller_account_reference_path, params: { reference: "" }

      assert_response :unprocessable_entity
      body = JSON.parse(response.body)

      assert_equal false, body["ok"]
      assert_match(/required/i, body["error"])
    end

    test "returns account history entries for known reference" do
      post teller_posting_path, params: {
        request_id: "acct-history-1",
        transaction_type: "deposit",
        amount_cents: 30_000,
        primary_account_reference: "acct:history-001",
        cash_account_reference: "cash:#{@drawer.code}"
      }

      get teller_account_history_path, params: { reference: "acct:history-001", limit: 5 }

      assert_response :success
      body = JSON.parse(response.body)

      assert_equal true, body["ok"]
      assert_equal "acct:history-001", body["reference"]
      assert_equal 1, body["entries"].size
      assert_equal "credit", body["entries"][0]["direction"]
      assert_equal 30_000, body["entries"][0]["amount_cents"]
      assert_equal 30_000, body["entries"][0]["signed_amount_cents"]
      assert_equal "deposit", body["entries"][0]["transaction_type"]
      assert_equal "acct-history-1", body["entries"][0]["request_id"]
    end

    test "returns unprocessable entity for blank history reference" do
      get teller_account_history_path, params: { reference: "" }

      assert_response :unprocessable_entity
      body = JSON.parse(response.body)

      assert_equal false, body["ok"]
      assert_match(/required/i, body["error"])
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
