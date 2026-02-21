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
      get teller_receipt_path(request_id: request_id)

      assert_response :success
      assert_select "h2", "Receipt / Audit"
      assert_select "p", /Request ID:\s+#{request_id}/
      assert_select "h3", "Posting Legs"
      assert_select "table"
    end

    private
      def grant_posting_access(user, branch, workstation)
        [
          "transactions.deposit.create",
          "transactions.withdrawal.create",
          "transactions.transfer.create"
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
