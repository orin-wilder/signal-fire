require "test_helper"

class Host::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = users(:host_user)
  end

  test "GET /host/dashboard redirects unauthenticated user to login" do
    get host_dashboard_path
    assert_redirected_to host_login_path
  end

  test "GET /host/dashboard renders for authenticated host" do
    post host_login_path, params: { email: @host.email, password: "password123" }
    get host_dashboard_path
    assert_response :success
  end

  test "GET /host/dashboard shows stats, greeting, and all totem events" do
    post host_login_path, params: { email: @host.email, password: "password123" }
    get host_dashboard_path
    assert_response :success
    assert_select "h1", text: /morning|afternoon|evening/i
    assert_select "div.divide-y"
    assert_match "Co-host Event", response.body
  end

  test "GET /host/dashboard filters by totem_id param" do
    post host_login_path, params: { email: @host.email, password: "password123" }
    get host_dashboard_path, params: { totem_id: totems(:main_totem).id }
    assert_response :success
  end

  test "GET /host/dashboard is inaccessible to non-host user" do
    regular = users(:regular_user)
    post host_login_path, params: { email: regular.email, password: "password123" }
    get host_dashboard_path
    assert_redirected_to host_login_path
  end

  test "GET /host redirects to /host/dashboard" do
    get host_root_path
    assert_redirected_to "/host/dashboard"
  end
end
