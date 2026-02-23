require "test_helper"

module Teller
  class DashboardControllerTest < ActionDispatch::IntegrationTest
    test "requires authentication" do
      get teller_root_path
      assert_redirected_to new_session_path
    end

    test "denies dashboard without permission" do
      user = User.take
      branch = Branch.create!(code: "998", name: "Unauthorized Branch")
      workstation = Workstation.create!(branch: branch, code: "U01", name: "Unauthorized WS")
      sign_in_as(user)
      set_signed_context(branch.id, workstation.id)

      get teller_root_path

      assert_redirected_to root_path
      follow_redirect!
      assert_select "div", /not authorized/i
    end

    test "shows dashboard for user with permission" do
      user = User.take
      branch = Branch.create!(code: "032", name: "Dashboard Branch")
      workstation = Workstation.create!(branch: branch, code: "D01", name: "Dashboard WS")
      grant_teller_dashboard_access(user, branch: branch, workstation: workstation)
      sign_in_as(user)
      set_signed_context(branch.id, workstation.id)

      get teller_root_path

      assert_response :success
      assert_select "h2", "Teller Transaction Flows"
      assert_select "a[href='#{new_teller_teller_session_path}']", "Session"
    end

    test "shows context setup page" do
      user = User.take
      branch = Branch.create!(code: "211", name: "Context Branch")
      workstation = Workstation.create!(branch: branch, code: "CTX1", name: "Context WS")
      grant_teller_dashboard_access(user, branch: branch, workstation: workstation)
      sign_in_as(user)

      get teller_context_path

      assert_response :success
      assert_select "h2", "Branch & Workstation Settings"
      assert_select "a[href='#{new_teller_teller_session_path}']", "Go to Session"
      assert_select "form[action='#{teller_context_path}'][method='post']"
    end

    test "updates context with valid branch and workstation" do
      user = User.take
      branch = Branch.create!(code: "011", name: "Main Branch")
      workstation = Workstation.create!(branch: branch, code: "T11", name: "Teller 01")
      grant_teller_dashboard_access(user, branch: branch, workstation: workstation)
      sign_in_as(user)

      patch teller_context_path, params: { branch_id: branch.id, workstation_id: workstation.id }

      assert_redirected_to new_teller_teller_session_path
    end

    test "rejects workstation from another branch" do
      user = User.take
      branch = Branch.create!(code: "012", name: "Main Branch")
      other_branch = Branch.create!(code: "013", name: "North Branch")
      workstation = Workstation.create!(branch: other_branch, code: "T12", name: "North Teller")
      grant_teller_dashboard_access(user, branch: branch)
      sign_in_as(user)

      patch teller_context_path, params: { branch_id: branch.id, workstation_id: workstation.id }

      assert_redirected_to teller_context_path
      follow_redirect!
      assert_response :success
      assert_select "div", /Workstation must belong to selected branch/
    end

    private
      def set_signed_context(branch_id, workstation_id)
        ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
          cookie_jar.signed[:current_branch_id] = branch_id
          cookie_jar.signed[:current_workstation_id] = workstation_id
          cookies["current_branch_id"] = cookie_jar["current_branch_id"]
          cookies["current_workstation_id"] = cookie_jar["current_workstation_id"]
        end
      end

      def grant_teller_dashboard_access(user, branch: nil, workstation: nil)
        permission = Permission.find_or_create_by!(key: "teller.dashboard.view") do |record|
          record.description = "Access teller dashboard"
        end

        role = Role.find_or_create_by!(key: "teller") do |record|
          record.name = "Teller"
        end

        RolePermission.find_or_create_by!(role: role, permission: permission)
        UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: workstation)
      end

      def grant_posting_access(user, branch:, workstation:)
        [ "transactions.deposit.create", "sessions.open" ].each do |permission_key|
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
