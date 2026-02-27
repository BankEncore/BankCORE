require "test_helper"

class LocksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email_address: "lock-user@example.com", password: "password", teller_number: "U01")
    @user.update_column(:password_hash, BCrypt::Password.create("1111").to_s)
    @supervisor = User.create!(email_address: "lock-supervisor@example.com", password: "password", teller_number: "S02")
    @supervisor.update_column(:password_hash, BCrypt::Password.create("2222").to_s)
    @other_user = User.create!(email_address: "lock-other@example.com", password: "password", teller_number: "U02")
    @other_user.update_column(:password_hash, BCrypt::Password.create("3333").to_s)

    @branch = Branch.create!(code: "701", name: "Lock Branch")
    @workstation = Workstation.create!(branch: @branch, code: "L1", name: "Lock WS")
    grant_supervisor_permissions(@supervisor, @branch, @workstation)
  end

  test "create locks session and redirects to lock screen" do
    sign_in_as(@user)
    post lock_path

    assert_redirected_to lock_path
    assert session[:session_locked]
    assert session[:locked_by_user_id] == @user.id
    assert_equal "session.locked", AuditEvent.order(:id).last.event_type
  end

  test "show redirects to default workspace when not locked" do
    sign_in_as(@user)
    get lock_path

    assert_redirected_to root_path
  end

  test "show renders locked screen when locked" do
    sign_in_as(@user)
    post lock_path
    get lock_path

    assert_response :success
    assert_select "h1", "Session Locked"
    assert_select "form[action=?]", lock_path
    assert_select "input[type=submit][value=Unlock]"
  end

  test "locked session blocks teller routes" do
    sign_in_as(@user)
    post lock_path
    get teller_root_path

    assert_redirected_to lock_path
  end

  test "locked session blocks csr routes" do
    sign_in_as(@user)
    patch csr_context_path, params: { branch_id: @branch.id }
    post lock_path
    get csr_root_path

    assert_redirected_to lock_path
  end

  test "locked session blocks ops routes" do
    sign_in_as(@user)
    post lock_path
    get ops_root_path

    assert_redirected_to lock_path
  end

  test "update unlocks with active user teller number and PIN" do
    sign_in_as(@user)
    post lock_path
    patch lock_path, params: { teller_number: @user.teller_number, pin: "1111" }

    assert_redirected_to root_path
    assert_nil session[:session_locked]
    assert_equal "session.unlock_succeeded", AuditEvent.order(:id).last.event_type
  end

  test "update unlocks with active user email and password" do
    sign_in_as(@user)
    post lock_path
    patch lock_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert_nil session[:session_locked]
  end

  test "update unlocks with supervisor credentials" do
    sign_in_as(@user)
    post lock_path
    patch lock_path, params: { teller_number: @supervisor.teller_number, pin: "2222" }

    assert_redirected_to root_path
    assert_nil session[:session_locked]
  end

  test "update fails with wrong credentials" do
    sign_in_as(@user)
    post lock_path
    patch lock_path, params: { teller_number: @user.teller_number, pin: "wrong" }

    assert_response :unprocessable_entity
    assert session[:session_locked]
    assert_equal "session.unlock_failed", AuditEvent.order(:id).last.event_type
  end

  test "update fails when non-supervisor tries to unlock another user session" do
    sign_in_as(@user)
    post lock_path
    patch lock_path, params: { teller_number: @other_user.teller_number, pin: "3333" }

    assert_response :forbidden
    assert session[:session_locked]
  end

  test "create requires authentication" do
    post lock_path

    assert_redirected_to new_session_path
  end

  private
    def grant_supervisor_permissions(user, branch, workstation)
      permission = Permission.find_or_create_by!(key: "approvals.override.execute") { |r| r.description = "Override" }
      role = Role.find_or_create_by!(key: "supervisor") { |r| r.name = "Supervisor" }
      RolePermission.find_or_create_by!(role: role, permission: permission)
      UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: workstation)
    end
end
