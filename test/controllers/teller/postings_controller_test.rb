require "test_helper"

module Teller
  class PostingsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = User.take
      @branch = Branch.create!(code: "401", name: "Post Branch")
      @workstation = Workstation.create!(branch: @branch, code: "PW1", name: "Post WS")
      @drawer = CashLocation.create!(
        branch: @branch,
        code: "PDR1",
        name: "Post Drawer",
        location_type: "drawer"
      )

      grant_permissions(@user, @branch, @workstation)
      sign_in_as(@user)
      patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }

      post teller_teller_session_path, params: { opening_cash_cents: 5_000, cash_location_id: @drawer.id }
    end

    test "creates a posting batch for balanced request" do
      post teller_posting_path, params: valid_posting_payload(request_id: "http-post-1")

      assert_response :success
      body = JSON.parse(response.body)

      assert_equal true, body["ok"]
      assert_equal 1, PostingBatch.where(request_id: "http-post-1").count
      assert_equal 1, TellerTransaction.where(request_id: "http-post-1").count
    end

    test "returns unprocessable entity for unbalanced request" do
      post teller_posting_path, params: valid_posting_payload(
        request_id: "http-post-2",
        entries: [
          { side: "debit", account_reference: "check:111000:222000:9001", amount_cents: 9_500 }
        ]
      )

      assert_response :unprocessable_entity
      body = JSON.parse(response.body)

      assert_equal false, body["ok"]
      assert_match(/unbalanced/i, body["error"])
      assert_equal 0, PostingBatch.where(request_id: "http-post-2").count
    end

    test "returns existing batch for duplicate request id" do
      post teller_posting_path, params: valid_posting_payload(request_id: "http-post-3")
      first_body = JSON.parse(response.body)

      post teller_posting_path, params: valid_posting_payload(request_id: "http-post-3")
      second_body = JSON.parse(response.body)

      assert_response :success
      assert_equal first_body["posting_batch_id"], second_body["posting_batch_id"]
      assert_equal 1, PostingBatch.where(request_id: "http-post-3").count
      assert_equal 1, TellerTransaction.where(request_id: "http-post-3").count
    end

    test "creates posting for explicit split deposit entries" do
      post teller_posting_path, params: valid_posting_payload(
        request_id: "http-post-4",
        amount_cents: 30_000,
        entries: [
          { side: "debit", account_reference: "cash:#{@drawer.code}", amount_cents: 10_000 },
          { side: "debit", account_reference: "check:111000:222000:9001", amount_cents: 20_000 },
          { side: "credit", account_reference: "acct:deposit", amount_cents: 30_000 }
        ]
      )

      assert_response :success
      body = JSON.parse(response.body)

      assert_equal true, body["ok"]
      assert_equal 1, PostingBatch.where(request_id: "http-post-4").count
      assert_equal 1, TellerTransaction.where(request_id: "http-post-4").count
    end

    test "stores approved_by_user_id when posting with approval token" do
      supervisor = User.create!(email_address: "posting-supervisor@example.com", password: "password")
      grant_supervisor_permissions(supervisor, @branch, @workstation)

      request_id = "http-post-approved-#{Time.current.to_i}"
      approval_token = ActiveSupport::MessageVerifier.new(Rails.application.secret_key_base, serializer: JSON).generate(
        {
          supervisor_user_id: supervisor.id,
          request_id: request_id,
          reason: "threshold_exceeded",
          policy_trigger: "amount_threshold",
          policy_context: {},
          approved_at: Time.current.to_i
        }
      )

      post teller_posting_path, params: valid_posting_payload(
        request_id: request_id,
        amount_cents: 150_000,
        entries: [
          { side: "debit", account_reference: "cash:#{@drawer.code}", amount_cents: 150_000 },
          { side: "credit", account_reference: "acct:deposit", amount_cents: 150_000 }
        ]
      ).merge(approval_token: approval_token)

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal true, body["ok"]

      tt = TellerTransaction.find_by!(request_id: request_id)
      assert_equal supervisor.id, tt.approved_by_user_id
      assert_equal supervisor, tt.approved_by_user
    end

    test "assigns server-generated request_id when request_id is blank" do
      post teller_posting_path, params: valid_posting_payload(request_id: "")

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal true, body["ok"]
      assert body["request_id"].present?, "Response should include request_id"
      assert_match(/\Aserver-\d+-[a-f0-9]+\z/, body["request_id"], "Request ID should be server-generated")
      assert_equal 1, TellerTransaction.where(request_id: body["request_id"]).count
    end

    test "persists check hold metadata into posting batch metadata" do
      post teller_posting_path, params: valid_posting_payload(
        request_id: "http-post-hold-1",
        amount_cents: 20_000,
        entries: [
          { side: "debit", account_reference: "check:111000:222000:9001", amount_cents: 20_000 },
          { side: "credit", account_reference: "acct:deposit", amount_cents: 20_000 }
        ]
      ).merge(
        check_items: [
          {
            routing: "111000",
            account: "222000",
            number: "9001",
            account_reference: "check:111000:222000:9001",
            amount_cents: 20_000,
            check_type: "transit",
            hold_reason: "large_item",
            hold_until: "2026-03-01"
          }
        ]
      )

      assert_response :success

      posting_batch = PostingBatch.find_by!(request_id: "http-post-hold-1")
      assert_equal "large_item", posting_batch.metadata.dig("check_items", 0, "hold_reason")
      assert_equal "2026-03-01", posting_batch.metadata.dig("check_items", 0, "hold_until")
      assert_equal "transit", posting_batch.metadata.dig("check_items", 0, "check_type")
      assert_equal "check:111000:222000:9001", posting_batch.metadata.dig("check_items", 0, "account_reference")
    end

    private
      def valid_posting_payload(request_id:, amount_cents: 10_000, entries: nil)
        {
          request_id: request_id,
          transaction_type: "deposit",
          amount_cents: amount_cents,
          primary_account_reference: "acct:deposit",
          cash_account_reference: "cash:#{@drawer.code}",
          entries: entries || [
            { side: "debit", account_reference: "acct:cash", amount_cents: 10_000 },
            { side: "credit", account_reference: "acct:deposit", amount_cents: 10_000 }
          ]
        }
      end

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

      def grant_supervisor_permissions(user, branch, workstation)
        [ "approvals.override.execute" ].each do |permission_key|
          permission = Permission.find_or_create_by!(key: permission_key) do |record|
            record.description = permission_key.humanize
          end

          role = Role.find_or_create_by!(key: "supervisor") do |record|
            record.name = "Supervisor"
          end

          RolePermission.find_or_create_by!(role: role, permission: permission)
          UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: workstation)
        end
      end
  end
end
