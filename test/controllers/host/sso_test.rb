require "test_helper"

class Host::SsoTest < ActionDispatch::IntegrationTest
  setup do
    @host_user    = users(:host_user)
    @regular_user = users(:regular_user)
  end

  # ── SSO token acceptance ─────────────────────────────────────────────

  test "valid SSO token signs in host and redirects to dashboard" do
    token = JwtService.encode(user_id: @host_user.id, exp: 5.minutes.from_now.to_i)
    get host_dashboard_path, params: { sso_token: token }
    assert_redirected_to host_dashboard_path
    follow_redirect!
    assert_response :success
  end

  test "expired SSO token is rejected" do
    token = JwtService.encode(user_id: @host_user.id, exp: 1.minute.ago.to_i)
    get host_dashboard_path, params: { sso_token: token }
    assert_redirected_to host_login_path
  end

  test "SSO token for non-host user is rejected" do
    token = JwtService.encode(user_id: @regular_user.id, exp: 5.minutes.from_now.to_i)
    get host_dashboard_path, params: { sso_token: token }
    assert_redirected_to host_login_path
  end

  test "tampered SSO token is rejected" do
    get host_dashboard_path, params: { sso_token: "not.a.valid.token" }
    assert_redirected_to host_login_path
  end
end
