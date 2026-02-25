require "test_helper"

module Teller
  class PostingChecksControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = User.take
      @branch = Branch.create!(code: "201", name: "Posting Branch")
      @workstation = Workstation.create!(branch: @branch, code: "PW1", name: "Posting WS")
      @drawer = CashLocation.create!(
        branch: @branch,
        code: "PDR1",
        name: "Posting Drawer",
        location_type: "drawer"
      )

      grant_permissions(@user, @branch, @workstation)
      sign_in_as(@user)
      patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }
    end

    test "blocks posting when no teller session is open" do
      post teller_posting_check_path

      assert_redirected_to new_teller_teller_session_path
      follow_redirect!
      assert_select "div", /Open a teller session before continuing\./i
    end

    test "blocks posting when opening without drawer" do
      post teller_teller_session_path, params: { opening_cash_cents: 1_000 }

      assert_redirected_to new_teller_teller_session_path
      assert_equal "Select a valid drawer.", flash[:alert]

      post teller_posting_check_path, params: { transaction_type: "deposit" }

      assert_redirected_to new_teller_teller_session_path
      follow_redirect!
      assert_select "div", /Open a teller session before continuing\./i
    end

    test "allows posting when session is open with drawer" do
      post teller_teller_session_path, params: { opening_cash_cents: 1_000, cash_location_id: @drawer.id }

      post teller_posting_check_path, params: { transaction_type: "deposit" }

      assert_response :success
      assert_equal({ "ok" => true, "message" => "Posting prerequisites satisfied" }, JSON.parse(response.body))
    end

    test "allows transfer check with session" do
      post teller_teller_session_path, params: { opening_cash_cents: 1_000, cash_location_id: @drawer.id }

      post teller_posting_check_path, params: { transaction_type: "transfer" }

      assert_response :success
      assert_equal({ "ok" => true, "message" => "Posting prerequisites satisfied" }, JSON.parse(response.body))
    end

    test "allows check cashing when session has drawer" do
      post teller_teller_session_path, params: { opening_cash_cents: 1_000, cash_location_id: @drawer.id }

      post teller_posting_check_path, params: { transaction_type: "check_cashing" }

      assert_response :success
      assert_equal({ "ok" => true, "message" => "Posting prerequisites satisfied" }, JSON.parse(response.body))
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
