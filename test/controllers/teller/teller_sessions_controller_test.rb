require "test_helper"

module Teller
  class TellerSessionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = User.take
      @branch = Branch.create!(code: "101", name: "Sprint Branch")
      @workstation = Workstation.create!(branch: @branch, code: "TS1", name: "Teller WS")
      @drawer = CashLocation.create!(
        branch: @branch,
        code: "DR1",
        name: "Drawer 1",
        location_type: "drawer"
      )
      grant_permissions(@user, @branch, @workstation)
      sign_in_as(@user)
      patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }
    end

    test "opens teller session" do
      post teller_teller_session_path, params: { opening_cash_cents: 10_000 }

      assert_redirected_to new_teller_teller_session_path
      assert_equal "open", TellerSession.last.status
      assert_equal 10_000, TellerSession.last.opening_cash_cents
      assert_equal "teller_session.opened", AuditEvent.last.event_type
    end

    test "assigns drawer to open teller session" do
      post teller_teller_session_path, params: { opening_cash_cents: 5_000 }

      patch assign_drawer_teller_teller_session_path, params: { cash_location_id: @drawer.id }

      assert_redirected_to teller_root_path
      session_record = TellerSession.last
      assert_equal @drawer.id, session_record.cash_location_id
      assert_equal "teller_session.drawer_assigned", AuditEvent.last.event_type
    end

    test "closes open teller session" do
      post teller_teller_session_path, params: { opening_cash_cents: 5_000 }

      patch assign_drawer_teller_teller_session_path, params: { cash_location_id: @drawer.id }

      teller_session = TellerSession.last
      deposit_tx = TellerTransaction.create!(
        user: @user,
        branch: @branch,
        workstation: @workstation,
        teller_session: teller_session,
        transaction_type: "deposit",
        amount_cents: 200,
        currency: "USD",
        request_id: "req-close-1",
        posted_at: Time.current
      )
      withdrawal_tx = TellerTransaction.create!(
        user: @user,
        branch: @branch,
        workstation: @workstation,
        teller_session: teller_session,
        transaction_type: "withdrawal",
        amount_cents: 50,
        currency: "USD",
        request_id: "req-close-2",
        posted_at: Time.current
      )

      CashMovement.create!(
        teller_transaction: deposit_tx,
        teller_session: teller_session,
        cash_location: @drawer,
        direction: "in",
        amount_cents: 200
      )
      CashMovement.create!(
        teller_transaction: withdrawal_tx,
        teller_session: teller_session,
        cash_location: @drawer,
        direction: "out",
        amount_cents: 50
      )

      patch close_teller_teller_session_path, params: {
        closing_cash_cents: 4_800,
        cash_variance_reason: "counting_error",
        cash_variance_notes: "Recounted twice; still short"
      }

      assert_redirected_to new_teller_teller_session_path
      session_record = TellerSession.last
      assert_equal "closed", session_record.status
      assert_equal 4_800, session_record.closing_cash_cents
      assert_equal 5_150, session_record.expected_closing_cash_cents
      assert_equal(-350, session_record.cash_variance_cents)
      assert_equal "counting_error", session_record.cash_variance_reason
      assert_equal "Recounted twice; still short", session_record.cash_variance_notes
      assert_equal "teller_session.closed", AuditEvent.last.event_type
    end

    test "shows dedicated teller session and drawer workflow page" do
      get new_teller_teller_session_path

      assert_response :success
      assert_select "h2", "Session"
      assert_select "h2", "Teller Session"
      assert_select "form[action='#{teller_teller_session_path}'][method='post']"
    end

    test "shows session page with close form when open session has drawer" do
      post teller_teller_session_path, params: { opening_cash_cents: 5_000 }
      patch assign_drawer_teller_teller_session_path, params: { cash_location_id: @drawer.id }

      get new_teller_teller_session_path

      assert_response :success
      assert_select "form[action='#{close_teller_teller_session_path}'][method='post']"
    end

    private
      def grant_permissions(user, branch, workstation)
        [ "teller.dashboard.view", "sessions.open", "sessions.close" ].each do |permission_key|
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
