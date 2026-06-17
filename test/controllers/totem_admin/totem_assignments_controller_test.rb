require "test_helper"

class TotemAdmin::TotemAssignmentsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @totem_admin = users(:totem_admin_user)
    @main        = totems(:main_totem)       # moderated by @totem_admin
    @secondary   = totems(:secondary_totem)  # NOT moderated by @totem_admin
  end

  test "new redirects non-moderators" do
    sign_in(users(:regular_user))
    get new_totem_admin_totem_assignment_path
    assert_redirected_to sign_in_path
  end

  test "totem admin can open the invite form" do
    sign_in(@totem_admin)
    get new_totem_admin_totem_assignment_path
    assert_response :success
    assert_select "form"
  end

  test "invites a brand-new host scoped to a moderated totem" do
    sign_in(@totem_admin)
    assert_difference ["User.count", "HostProfile.count", "HostTotemAssignment.count"], 1 do
      assert_emails 1 do
        post totem_admin_totem_assignments_path,
          params: { totem_id: @main.id, name: "New Host", email: "newhost@example.com" }
      end
    end
    assert_redirected_to totem_admin_totems_path

    user       = User.find_by!(email: "newhost@example.com")
    assignment = HostTotemAssignment.find_by!(host_user_id: user.id, totem_id: @main.id)
    assert assignment.role_host?
    assert_equal @totem_admin.id, assignment.assigned_by_admin_id
  end

  test "assigns an existing user without re-inviting" do
    existing = users(:regular_user)
    sign_in(@totem_admin)
    assert_no_difference ["User.count"] do
      assert_emails 0 do
        post totem_admin_totem_assignments_path,
          params: { totem_id: @main.id, name: existing.name, email: existing.email }
      end
    end
    assert HostTotemAssignment.exists?(host_user_id: existing.id, totem_id: @main.id)
  end

  test "cannot assign a host to a totem outside moderated scope" do
    sign_in(@totem_admin)
    assert_no_difference ["User.count", "HostTotemAssignment.count"] do
      post totem_admin_totem_assignments_path,
        params: { totem_id: @secondary.id, name: "Sneaky", email: "sneaky@example.com" }
    end
    assert_redirected_to totem_admin_totems_path
    assert flash[:alert].present?
  end

  private

  def sign_in(user)
    post sign_in_path, params: { email: user.email, password: "password123" }
  end
end
