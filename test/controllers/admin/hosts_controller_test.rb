require "test_helper"

class Admin::HostsControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup do
    @admin        = users(:admin_user)
    @host         = users(:host_user)
    @invited_host = users(:invited_host_user)
    @totem        = totems(:main_totem)
    @secondary    = totems(:secondary_totem)
  end

  # ── Auth guard ────────────────────────────────────────────────────────────

  test "GET /admin/hosts redirects to login when not signed in" do
    get admin_hosts_path
    assert_redirected_to admin_login_path
  end

  # ── Index ─────────────────────────────────────────────────────────────────

  test "GET /admin/hosts lists all hosts" do
    sign_in_as_admin
    get admin_hosts_path
    assert_response :success
    assert_select "h1", text: /hosts/i
    assert_select "td", text: /Host User/i
  end

  test "GET /admin/hosts?status=active filters to active hosts only" do
    sign_in_as_admin
    get admin_hosts_path, params: { status: "active" }
    assert_response :success
    assert_select "td", text: /Invited Host/i, count: 0
  end

  test "GET /admin/hosts?status=invited filters to invited hosts only" do
    sign_in_as_admin
    get admin_hosts_path, params: { status: "invited" }
    assert_response :success
    assert_select "td", text: /Host User/i, count: 0
  end

  test "GET /admin/hosts?status=deactivated filters to deactivated hosts only" do
    sign_in_as_admin
    get admin_hosts_path, params: { status: "deactivated" }
    assert_response :success
    assert_select "td", text: /Deactivated Host/i
    assert_select "td", text: /Host User/i, count: 0
  end

  test "GET /admin/hosts shows event counts" do
    sign_in_as_admin
    get admin_hosts_path
    assert_response :success
  end

  # ── New / Create (invite) ─────────────────────────────────────────────────

  test "GET /admin/hosts/new renders invite form" do
    sign_in_as_admin
    get new_admin_host_path
    assert_response :success
    assert_select "form"
    assert_select "input[name='email']"
    assert_select "input[name='name']"
  end

  test "POST /admin/hosts creates user and host_profile and sends invite email" do
    sign_in_as_admin
    assert_difference ["User.count", "HostProfile.count"], 1 do
      assert_emails 1 do
        post admin_hosts_path, params: { name: "New Host", email: "newhost@example.com" }
      end
    end
    assert_redirected_to admin_hosts_path
    assert flash[:notice].present?

    user    = User.find_by!(email: "newhost@example.com")
    profile = user.host_profile
    assert user.is_host
    assert_equal "email", user.auth_method
    assert_equal "New Host", profile.display_name
    assert_equal "invited", profile.invite_status
    assert profile.invitation_token.present?
    assert profile.invitation_token_expires_at > Time.current
  end

  test "POST /admin/hosts with duplicate email re-renders form with error" do
    sign_in_as_admin
    assert_no_difference "User.count" do
      post admin_hosts_path, params: { name: "Dupe", email: @host.email }
    end
    assert_response :unprocessable_entity
  end

  test "POST /admin/hosts with blank email re-renders form with error" do
    sign_in_as_admin
    assert_no_difference "User.count" do
      post admin_hosts_path, params: { name: "No Email", email: "" }
    end
    assert_response :unprocessable_entity
  end

  # ── Edit / Update ─────────────────────────────────────────────────────────

  test "GET /admin/hosts/:id/edit renders form with totem checkboxes" do
    sign_in_as_admin
    get edit_admin_host_path(@host)
    assert_response :success
    assert_select "input[type='checkbox']"
  end

  test "PATCH /admin/hosts/:id updates name and email" do
    sign_in_as_admin
    patch admin_host_path(@host), params: {
      host: { name: "Updated Name", email: "updated@example.com", totem_ids: [] }
    }
    assert_redirected_to admin_hosts_path
    assert_equal "updated@example.com", @host.reload.email
    assert_equal "Updated Name", @host.host_profile.reload.display_name
  end

  test "PATCH /admin/hosts/:id saves host_story on host_profile" do
    sign_in_as_admin
    patch admin_host_path(@host), params: {
      host: { name: @host.name, email: @host.email,
              host_story: "Been running Sunday jams since 2021.", totem_ids: [] }
    }
    assert_redirected_to admin_hosts_path
    assert_equal "Been running Sunday jams since 2021.", @host.host_profile.reload.host_story
  end

  test "GET /admin/hosts/:id/edit form includes host_story textarea" do
    sign_in_as_admin
    get edit_admin_host_path(@host)
    assert_response :success
    assert_select "textarea[name='host[host_story]']"
  end

  test "PATCH /admin/hosts/:id assigns totems" do
    sign_in_as_admin
    patch admin_host_path(@host), params: {
      host: { name: @host.name, email: @host.email, totem_ids: [@secondary.id] }
    }
    assert_redirected_to admin_hosts_path
    assert_includes @host.reload.assigned_totems, @secondary
  end

  test "PATCH /admin/hosts/:id removes totem assignments not in submitted list" do
    sign_in_as_admin
    # host_user is currently assigned to main_totem via fixture
    patch admin_host_path(@host), params: {
      host: { name: @host.name, email: @host.email, totem_ids: [""] }
    }
    assert_redirected_to admin_hosts_path
    assert_empty @host.reload.assigned_totems
  end

  test "PATCH /admin/hosts/:id assigns a per-totem role" do
    sign_in_as_admin
    patch admin_host_path(@host), params: {
      host: { name: @host.name, email: @host.email,
              totem_ids: [@secondary.id],
              totem_roles: { @secondary.id.to_s => "totem_admin" } }
    }
    assert_redirected_to admin_hosts_path
    assignment = HostTotemAssignment.find_by!(host_user_id: @host.id, totem_id: @secondary.id)
    assert assignment.role_totem_admin?
  end

  test "PATCH /admin/hosts/:id defaults role to host when unspecified" do
    sign_in_as_admin
    patch admin_host_path(@host), params: {
      host: { name: @host.name, email: @host.email, totem_ids: [@secondary.id] }
    }
    assert_redirected_to admin_hosts_path
    assignment = HostTotemAssignment.find_by!(host_user_id: @host.id, totem_id: @secondary.id)
    assert assignment.role_host?
  end

  test "GET /admin/hosts/:id/edit renders a role select per totem" do
    sign_in_as_admin
    get edit_admin_host_path(@host)
    assert_response :success
    assert_select "select[name='host[totem_roles][#{@secondary.id}]']"
  end

  # ── Destroy ───────────────────────────────────────────────────────────────

  test "DELETE /admin/hosts/:id destroys host with no events" do
    sign_in_as_admin
    user = User.create!(email: "deletable@example.com", name: "Deletable", is_host: true, auth_method: :email)
    HostProfile.create!(user: user, display_name: "Deletable", invite_status: :invited, invited_at: Time.current)

    assert_difference "User.count", -1 do
      delete admin_host_path(user)
    end
    assert_redirected_to admin_hosts_path
  end

  test "DELETE /admin/hosts/:id is blocked when host has events" do
    sign_in_as_admin
    assert_no_difference "User.count" do
      delete admin_host_path(@host)
    end
    assert_redirected_to admin_hosts_path
    assert flash[:alert].present?
  end

  # ── Deactivate / Activate ─────────────────────────────────────────────────

  test "PATCH /admin/hosts/:id/deactivate sets invite_status to deactivated" do
    sign_in_as_admin
    patch deactivate_admin_host_path(@host)
    assert_redirected_to admin_hosts_path
    assert_equal "deactivated", @host.host_profile.reload.invite_status
  end

  test "PATCH /admin/hosts/:id/activate sets invite_status to active" do
    sign_in_as_admin
    patch activate_admin_host_path(users(:deactivated_host_user))
    assert_redirected_to admin_hosts_path
    assert_equal "active", users(:deactivated_host_user).host_profile.reload.invite_status
  end

  private

  def sign_in_as_admin
    post admin_login_path, params: { email: @admin.email, password: "password123" }
  end
end
