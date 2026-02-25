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

    test "opens teller session with drawer" do
      post teller_teller_session_path, params: {
        opening_cash_cents: 10_000,
        cash_location_id: @drawer.id
      }

      assert_redirected_to teller_root_path
      session_record = TellerSession.last
      assert_equal "open", session_record.status
      assert_equal 10_000, session_record.opening_cash_cents
      assert_equal @drawer.id, session_record.cash_location_id
      assert_equal "teller_session.opened", AuditEvent.last.event_type
    end

    test "posts handoff variance when opening differs from previous closing" do
      previous_session = TellerSession.create!(
        user: @user,
        branch: @branch,
        workstation: @workstation,
        cash_location: @drawer,
        status: "closed",
        opened_at: 1.hour.ago,
        closed_at: Time.current,
        opening_cash_cents: 5_000,
        closing_cash_cents: 5_200,
        expected_closing_cash_cents: 5_200
      )

      post teller_teller_session_path, params: {
        opening_cash_cents: 5_100,
        cash_location_id: @drawer.id
      }

      assert_redirected_to teller_root_path
      session_record = TellerSession.last
      assert_equal 5_100, session_record.opening_cash_cents

      handoff_tx = TellerTransaction.find_by(
        teller_session: session_record,
        transaction_type: "session_handoff_variance"
      )
      assert_not_nil handoff_tx
      assert_equal 100, handoff_tx.amount_cents
      assert_equal 2, handoff_tx.posting_batch.posting_legs.count
    end

    test "closes open teller session" do
      TellerSession.create!(
        user: @user,
        branch: @branch,
        workstation: @workstation,
        cash_location: @drawer,
        status: "closed",
        opened_at: 2.hours.ago,
        closed_at: 1.hour.ago,
        opening_cash_cents: 5_000,
        closing_cash_cents: 5_000,
        expected_closing_cash_cents: 5_000
      )

      post teller_teller_session_path, params: {
        opening_cash_cents: 5_000,
        cash_location_id: @drawer.id
      }

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

    test "posts close variance when declared differs from expected" do
      TellerSession.create!(
        user: @user,
        branch: @branch,
        workstation: @workstation,
        cash_location: @drawer,
        status: "closed",
        opened_at: 2.hours.ago,
        closed_at: 1.hour.ago,
        opening_cash_cents: 5_000,
        closing_cash_cents: 5_000,
        expected_closing_cash_cents: 5_000
      )

      post teller_teller_session_path, params: {
        opening_cash_cents: 5_000,
        cash_location_id: @drawer.id
      }

      teller_session = TellerSession.last

      patch close_teller_teller_session_path, params: {
        closing_cash_cents: 4_800,
        cash_variance_reason: "short"
      }

      close_tx = TellerTransaction.find_by(
        teller_session: teller_session,
        transaction_type: "session_close_variance"
      )
      assert_not_nil close_tx
      assert_equal 200, close_tx.amount_cents
      assert_equal 2, close_tx.posting_batch.posting_legs.count
      short_leg = close_tx.posting_batch.posting_legs.find_by(account_reference: "expense:cash_short")
      assert_not_nil short_leg
      assert_equal 200, short_leg.amount_cents
    end

    test "previous_closing returns last closing for drawer" do
      TellerSession.create!(
        user: @user,
        branch: @branch,
        workstation: @workstation,
        cash_location: @drawer,
        status: "closed",
        opened_at: 2.hours.ago,
        closed_at: 1.hour.ago,
        opening_cash_cents: 0,
        closing_cash_cents: 7_500,
        expected_closing_cash_cents: 7_500
      )

      get previous_closing_teller_teller_session_path, params: { cash_location_id: @drawer.id }

      assert_response :success
      json = response.parsed_body
      assert_equal 7_500, json["previous_closing_cents"]
    end

    test "shows dedicated teller session and drawer workflow page" do
      get new_teller_teller_session_path

      assert_response :success
      assert_select "h2", "Session"
      assert_select "h2", "Teller Session"
      assert_select "form[action='#{teller_teller_session_path}'][method='post']"
      assert_select "select[name*='cash_location_id']"
    end

    test "shows session page with close form when open session has drawer" do
      post teller_teller_session_path, params: {
        opening_cash_cents: 5_000,
        cash_location_id: @drawer.id
      }

      get new_teller_teller_session_path

      assert_response :success
      assert_select "form[action='#{close_teller_teller_session_path}'][method='post']"
    end

    test "rejects open without drawer" do
      post teller_teller_session_path, params: { opening_cash_cents: 5_000 }

      assert_redirected_to new_teller_teller_session_path
      assert_equal "Select a valid drawer.", flash[:alert]
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
