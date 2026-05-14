require "test_helper"

class HostFollowsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user      = users(:regular_user)
    @host_user = users(:host_user)
    sign_in(@user)
  end

  # ── Auth guard ────────────────────────────────────────────────────────────

  test "POST /host_follows redirects to sign in when not signed in" do
    delete sign_out_path
    post host_follows_path, params: { host_user_id: @host_user.id }
    assert_redirected_to sign_in_path
  end

  test "DELETE /host_follows/:id redirects to sign in when not signed in" do
    follow = HostFollow.create!(user: @user, host_user: @host_user)
    delete sign_out_path
    delete host_follow_path(follow)
    assert_redirected_to sign_in_path
  end

  # ── Create ────────────────────────────────────────────────────────────────

  test "POST /host_follows creates follow for signed-in user" do
    assert_difference "HostFollow.count", 1 do
      post host_follows_path, params: { host_user_id: @host_user.id }
    end
    assert HostFollow.exists?(user: @user, host_user: @host_user)
  end

  test "POST /host_follows is idempotent for existing follow" do
    HostFollow.create!(user: @user, host_user: @host_user)
    assert_no_difference "HostFollow.count" do
      post host_follows_path, params: { host_user_id: @host_user.id }
    end
  end

  test "POST /host_follows redirects back" do
    post host_follows_path, params: { host_user_id: @host_user.id }
    assert_response :redirect
  end

  # ── Destroy ───────────────────────────────────────────────────────────────

  test "DELETE /host_follows/:id removes the follow" do
    follow = HostFollow.create!(user: @user, host_user: @host_user)
    assert_difference "HostFollow.count", -1 do
      delete host_follow_path(follow)
    end
  end

  test "DELETE /host_follows/:id returns 404 for another user's follow" do
    other_user = users(:follower_user)
    follow = HostFollow.create!(user: other_user, host_user: @host_user)
    assert_no_difference "HostFollow.count" do
      delete host_follow_path(follow)
    end
    assert_response :not_found
  end

  private

  def sign_in(user)
    user.generate_magic_link_token!
    get verify_magic_link_path, params: { token: user.magic_link_token }
  end
end
