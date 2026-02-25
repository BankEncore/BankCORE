require "test_helper"

module Teller
  class ReceiptsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = User.take || User.create!(email_address: "receipt-user@example.com", password: "password")
      @branch = Branch.create!(code: "901", name: "Receipt Branch")
      @workstation = Workstation.create!(branch: @branch, code: "RC1", name: "Receipt WS")
      @drawer = CashLocation.create!(branch: @branch, code: "RDR1", name: "Receipt Drawer", location_type: "drawer")
      @teller_session = TellerSession.create!(
        user: @user,
        branch: @branch,
        workstation: @workstation,
        cash_location: @drawer,
        status: "open",
        opened_at: Time.current,
        opening_cash_cents: 10_000
      )

      grant_posting_access(@user, @branch, @workstation)
    end

    test "requires authentication" do
      get teller_receipt_path(request_id: "missing")
      assert_redirected_to new_session_path
    end

    test "renders receipt for posted transaction" do
      request_id = "req-receipt-1"
      Posting::Engine.new(
        user: @user,
        teller_session: @teller_session,
        branch: @branch,
        workstation: @workstation,
        request_id: request_id,
        transaction_type: "deposit",
        amount_cents: 10_00,
        entries: [
          { side: "debit", account_reference: "cash:#{@drawer.code}", amount_cents: 10_00 },
          { side: "credit", account_reference: "acct:deposit", amount_cents: 10_00 }
        ]
      ).call

      sign_in_as(@user)
      set_signed_context(@branch.id, @workstation.id)
      get teller_receipt_path(request_id: request_id)

      assert_response :success
      assert_select "h2", "Receipt"
      assert_select ".receipt-type-title", "DEPOSIT"
      assert_select ".receipt-header"
    end

    test "renders check cashing details when metadata is present" do
      request_id = "req-receipt-check-cashing-1"
      Posting::Engine.new(
        user: @user,
        teller_session: @teller_session,
        branch: @branch,
        workstation: @workstation,
        request_id: request_id,
        transaction_type: "check_cashing",
        amount_cents: 9_500,
        metadata: {
          check_cashing: {
            check_amount_cents: 10_000,
            fee_cents: 500,
            net_cash_payout_cents: 9_500,
            fee_income_account_reference: "income:check_cashing_fee",
            id_type: "drivers_license",
            id_number: "D1234567",
            check_items: [
              { "routing" => "021000021", "account" => "123456789", "number" => "1000123", "amount_cents" => 10_000 }
            ]
          }
        },
        entries: [
          { side: "debit", account_reference: "acct:settlement", amount_cents: 10_000 },
          { side: "credit", account_reference: "cash:#{@drawer.code}", amount_cents: 9_500 },
          { side: "credit", account_reference: "income:check_cashing_fee", amount_cents: 500 }
        ]
      ).call

      sign_in_as(@user)
      set_signed_context(@branch.id, @workstation.id)
      get teller_receipt_path(request_id: request_id)

      assert_response :success
      assert_select ".receipt-type-title", /check cashing/i
      assert_select ".receipt-printable", /Checks In:\s+\$100\.00/
      assert_select ".receipt-printable", /Fee:\s+\$5\.00/
      assert_select ".receipt-printable", /Disbursement:\s+\$95\.00/
    end

    test "renders draft details when metadata is present" do
      request_id = "req-receipt-draft-1"
      Posting::Engine.new(
        user: @user,
        teller_session: @teller_session,
        branch: @branch,
        workstation: @workstation,
        request_id: request_id,
        transaction_type: "draft",
        amount_cents: 10_250,
        metadata: {
          draft: {
            funding_source: "account",
            draft_amount_cents: 10_000,
            fee_cents: 250,
            payee_name: "City Utilities",
            instrument_number: "OD-2001",
            liability_account_reference: "official_check:outstanding",
            fee_income_account_reference: "income:draft_fee"
          }
        },
        entries: [
          { side: "debit", account_reference: "acct:customer", amount_cents: 10_000 },
          { side: "credit", account_reference: "official_check:outstanding", amount_cents: 10_000 },
          { side: "debit", account_reference: "acct:customer", amount_cents: 250 },
          { side: "credit", account_reference: "income:draft_fee", amount_cents: 250 }
        ]
      ).call

      sign_in_as(@user)
      set_signed_context(@branch.id, @workstation.id)
      get teller_receipt_path(request_id: request_id)

      assert_response :success
      assert_select ".receipt-type-title", "DRAFT"
      assert_select ".receipt-printable", /Draft #:\s+OD-2001/
      assert_select ".receipt-printable", /Amount:\s+\$100\.00/
      assert_select ".receipt-printable", /Fee:\s+\$2\.50/
      assert_select ".receipt-printable", /Total Due:\s+\$102\.50/
    end

    test "renders vault transfer details when metadata is present" do
      request_id = "req-receipt-vault-1"
      Posting::Engine.new(
        user: @user,
        teller_session: @teller_session,
        branch: @branch,
        workstation: @workstation,
        request_id: request_id,
        transaction_type: "vault_transfer",
        amount_cents: 12_000,
        metadata: {
          vault_transfer: {
            direction: "drawer_to_vault",
            source_cash_account_reference: "cash:#{@drawer.code}",
            destination_cash_account_reference: "cash:V01",
            reason_code: "excess_cash",
            memo: "Evening pull"
          }
        },
        entries: [
          { side: "debit", account_reference: "cash:V01", amount_cents: 12_000 },
          { side: "credit", account_reference: "cash:#{@drawer.code}", amount_cents: 12_000 }
        ]
      ).call

      sign_in_as(@user)
      set_signed_context(@branch.id, @workstation.id)
      get teller_receipt_path(request_id: request_id)

      assert_response :success
      assert_select ".receipt-type-title", /vault transfer/i
      assert_select "p", /Reason:\s+Excess cash/i
      assert_select "p", /Amount:\s+\$120\.00/
    end

    private
      def set_signed_context(branch_id, workstation_id) # test
        ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
          cookie_jar.signed[:current_branch_id] = branch_id
          cookie_jar.signed[:current_workstation_id] = workstation_id
          cookies["current_branch_id"] = cookie_jar["current_branch_id"]
          cookies["current_workstation_id"] = cookie_jar["current_workstation_id"]
        end
      end

      def grant_posting_access(user, branch, workstation)
        [
          "transactions.deposit.create",
          "transactions.withdrawal.create",
          "transactions.transfer.create",
          "transactions.vault_transfer.create",
          "transactions.draft.create",
          "transactions.check_cashing.create"
        ].each do |permission_key|
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
