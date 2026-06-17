require "test_helper"

class Admin::TotemAssignmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin     = users(:admin_user)
    @main      = totems(:main_totem)
    @secondary = totems(:secondary_totem)
  end

  test "redirects when not signed in as admin" do
    get new_admin_totem_assignment_path
    assert_redirected_to admin_login_path
  end

  test "admin can open the assignment form" do
    sign_in_as_admin
    get new_admin_totem_assignment_path
    assert_response :success
    assert_select "select[name='role']"
  end

  test "grants a non-host user a totem_admin role" do
    sign_in_as_admin
    user = users(:regular_user)
    assert_difference "HostTotemAssignment.count", 1 do
      post admin_totem_assignments_path,
        params: { user_id: user.id, totem_id: @secondary.id, role: "totem_admin" }
    end
    assignment = HostTotemAssignment.find_by!(host_user_id: user.id, totem_id: @secondary.id)
    assert assignment.role_totem_admin?
    assert_equal @admin.id, assignment.assigned_by_admin_id
  end

  test "updates the role of an existing assignment" do
    sign_in_as_admin
    host = users(:host_user) # already host on main_totem via fixture
    assert_no_difference "HostTotemAssignment.count" do
      post admin_totem_assignments_path,
        params: { user_id: host.id, totem_id: @main.id, role: "totem_admin" }
    end
    assignment = HostTotemAssignment.find_by!(host_user_id: host.id, totem_id: @main.id)
    assert assignment.role_totem_admin?
  end

  test "defaults to host for an unknown role value" do
    sign_in_as_admin
    user = users(:regular_user)
    post admin_totem_assignments_path,
      params: { user_id: user.id, totem_id: @secondary.id, role: "bogus" }
    assignment = HostTotemAssignment.find_by!(host_user_id: user.id, totem_id: @secondary.id)
    assert assignment.role_host?
  end

  private

  def sign_in_as_admin
    post admin_login_path, params: { email: @admin.email, password: "password123" }
  end
end
