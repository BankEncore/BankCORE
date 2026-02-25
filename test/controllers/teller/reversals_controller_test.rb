require "test_helper"

module Teller
  class ReversalsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = User.take || User.create!(email_address: "reversal-ctrl@example.com", password: "password")
      @supervisor = User.create!(email_address: "reversal-supervisor@example.com", password: "password")
      @branch = Branch.create!(code: "996", name: "Reversal Ctrl Branch")
      @workstation = Workstation.create!(branch: @branch, code: "RC1", name: "Reversal Ctrl WS")
      @drawer = CashLocation.create!(
        branch: @branch,
        code: "RCD1",
        name: "Reversal Ctrl Drawer",
        location_type: "drawer"
      )
      @teller_session = TellerSession.create!(
        user: @user,
        branch: @branch,
        workstation: @workstation,
        cash_location: @drawer,
        status: "open",
        opened_at: Time.current,
        opening_cash_cents: 10_000
      )
      @original = create_deposit_transaction
      grant_posting_access(@user, @branch, @workstation)
      grant_supervisor_access(@supervisor, @branch, @workstation)

      sign_in_as(@user)
      patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }
      post teller_teller_session_path, params: { opening_cash_cents: 10_000, cash_location_id: @drawer.id }
    end

    test "GET reversal renders new form when transaction is reversible" do
      get reversal_teller_transaction_path(@original)

      assert_response :success
      assert_select "h2", "Reversal"
      assert_select "form" do
        assert_select "[name=?]", "reversal_reason_code"
        assert_select "[name=?]", "reversal_memo"
      end
      assert_select "dl", /#{@original.request_id}/
      assert_select "dl", /#{@original.transaction_type.titleize}/
    end

    test "GET reversal redirects when transaction is not reversible" do
      variance = create_variance_transaction

      get reversal_teller_transaction_path(variance)

      assert_redirected_to teller_root_path
      assert_equal "This transaction cannot be reversed.", flash[:alert]
    end

    test "GET reversal redirects when transaction not found" do
      get reversal_teller_transaction_path(id: 999999)

      assert_redirected_to teller_root_path
      assert_equal "Transaction not found.", flash[:alert]
    end

    test "POST reversal creates reversal with valid approval" do
      request_id = "reversal-test-#{@original.id}-#{Time.current.to_i}"
      approval_token = create_approval_token(request_id)

      assert_difference "TellerTransaction.count", 1 do
        assert_difference "PostingBatch.count", 1 do
          post reversal_teller_transaction_path(@original), params: {
            reversal_reason_code: "ENTRY_ERROR",
            reversal_memo: "Wrong account entered",
            approval_token: approval_token,
            request_id: request_id
          }
        end
      end

      assert_redirected_to teller_receipt_path(request_id: request_id)
      assert_equal "Reversal posted successfully.", flash[:notice]

      @original.reload
      assert @original.reversed?
    end

    test "POST reversal requires approval token" do
      post reversal_teller_transaction_path(@original), params: {
        reversal_reason_code: "ENTRY_ERROR",
        reversal_memo: "Test",
        request_id: "reversal-no-token-#{@original.id}-#{Time.current.to_i}"
      }

      assert_response :unprocessable_entity
      assert_match /approval/i, flash[:alert]
    end

    private

    def create_deposit_transaction
      batch = Posting::Engine.new(
        user: @user,
        teller_session: @teller_session,
        branch: @branch,
        workstation: @workstation,
        request_id: "deposit-rev-ctrl-#{SecureRandom.hex(4)}",
        transaction_type: "deposit",
        amount_cents: 5_000,
        entries: [
          { side: "debit", account_reference: "cash:#{@drawer.code}", amount_cents: 5_000 },
          { side: "credit", account_reference: "1000000000001001", amount_cents: 5_000 }
        ]
      ).call
      batch.teller_transaction
    end

    def create_variance_transaction
      tt = TellerTransaction.create!(
        user: @user,
        teller_session: @teller_session,
        branch: @branch,
        workstation: @workstation,
        request_id: "variance-rev-#{SecureRandom.hex(4)}",
        transaction_type: "session_close_variance",
        amount_cents: 100,
        currency: "USD",
        status: "posted",
        posted_at: Time.current
      )
      PostingBatch.create!(
        teller_transaction: tt,
        request_id: tt.request_id,
        currency: "USD",
        status: "committed",
        committed_at: Time.current,
        metadata: {}
      )
      PostingLeg.create!(posting_batch: tt.posting_batch, side: "debit", account_reference: "cash:#{@drawer.code}", amount_cents: 100, position: 0)
      PostingLeg.create!(posting_batch: tt.posting_batch, side: "credit", account_reference: "income:variance", amount_cents: 100, position: 1)
      tt
    end

    def create_approval_token(request_id)
      verifier = ActiveSupport::MessageVerifier.new(Rails.application.secret_key_base, serializer: JSON)
      verifier.generate(
        {
          supervisor_user_id: @supervisor.id,
          request_id: request_id,
          reason: "Reversal approval",
          policy_trigger: "transaction_reversal",
          policy_context: {},
          approved_at: Time.current.to_i
        },
        expires_in: 10.minutes
      )
    end

    def grant_posting_access(user, branch, workstation)
      [
        "sessions.open",
        "transactions.deposit.create",
        "transactions.reversal.create"
      ].each do |permission_key|
        permission = Permission.find_or_create_by!(key: permission_key) { |r| r.description = permission_key }
        role = Role.find_or_create_by!(key: "teller") { |r| r.name = "Teller" }
        RolePermission.find_or_create_by!(role: role, permission: permission)
        UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: workstation)
      end
    end

    def grant_supervisor_access(user, branch, workstation)
      permission = Permission.find_or_create_by!(key: "approvals.override.execute") { |r| r.description = "Override" }
      role = Role.find_or_create_by!(key: "supervisor") { |r| r.name = "Supervisor" }
      RolePermission.find_or_create_by!(role: role, permission: permission)
      UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: workstation)
    end
  end
end
