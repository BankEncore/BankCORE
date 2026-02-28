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
      post teller_teller_session_path, params: { opening_cash_cents: 10_000, cash_location_id: @drawer.id }
      @party = Party.where(party_kind: "individual").first || Party.create!(party_kind: "individual", relationship_kind: "customer", display_name: "AcctRef Party", is_active: true)
    end

    test "returns account snapshot for known account reference" do
      post teller_posting_path, params: {
        request_id: "acct-ref-1",
        transaction_type: "deposit",
        amount_cents: 25_000,
        party_id: @party.id,
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
        party_id: @party.id,
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

    test "returns balance and history by account_id when reference matches Account" do
      account = Account.create!(
        account_number: "5555555555555555",
        account_type: "checking",
        branch: @branch,
        status: "open",
        opened_on: Date.current,
        last_activity_at: Time.current
      )

      post teller_posting_path, params: {
        request_id: "acct-id-lookup-1",
        transaction_type: "deposit",
        amount_cents: 42_000,
        party_id: @party.id,
        primary_account_reference: account.account_number,
        cash_account_reference: "cash:#{@drawer.code}"
      }

      account.update!(account_number: "6666666666666666")

      get teller_account_reference_path, params: { reference: "6666666666666666" }
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal true, body["ok"]
      assert_equal true, body["found"]
      assert_equal 42_000, body["ledger_balance_cents"]

      get teller_account_history_path, params: { reference: "6666666666666666", limit: 5 }
      assert_response :success
      body = JSON.parse(response.body)
      assert_equal true, body["ok"]
      assert_equal 1, body["entries"].size
      assert_equal 42_000, body["entries"][0]["amount_cents"]
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
