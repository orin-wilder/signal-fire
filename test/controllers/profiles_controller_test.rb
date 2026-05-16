require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @regular_user    = users(:regular_user)
    @follower_user   = users(:follower_user)   # has totem favorite
    @subscriber_user = users(:subscriber_user)  # has host follow
    @host_user       = users(:host_user)
  end

  # ── Auth ────────────────────────────────────────────────────────────

  test "redirects to sign in when not signed in" do
    get user_profile_path
    assert_redirected_to sign_in_path
  end

  # ── Basic rendering ──────────────────────────────────────────────────

  test "returns 200 for signed-in user" do
    sign_in @regular_user
    get user_profile_path
    assert_response :success
  end

  test "renders favorite places section" do
    sign_in @follower_user
    get user_profile_path
    assert_select "h2", text: /Favorite places/i
    assert_response :success
  end

  test "renders a totem favorite in the list" do
    sign_in @follower_user
    get user_profile_path
    fav = @follower_user.totem_favorites.first
    assert_select "span", text: fav.totem.name
  end

  test "renders host follows section" do
    sign_in @subscriber_user
    get user_profile_path
    assert_select "h2", text: /Hosts you follow/i
  end

  test "renders empty state for favorites when none exist" do
    sign_in @regular_user
    get user_profile_path
    assert_select "p", text: /haven't favorited any places/i
  end

  test "renders empty state for follows when none exist" do
    sign_in @regular_user
    get user_profile_path
    assert_select "p", text: /not following any hosts/i
  end

  # ── Hosted events row ────────────────────────────────────────────────

  test "hosted events row is hidden for regular users" do
    sign_in @regular_user
    get user_profile_path
    assert_select "h2", text: /your events/i, count: 0
  end

  test "hosted events row is visible for host users" do
    sign_in @host_user
    get user_profile_path
    assert_select "h2", text: /your events/i
    assert_select "a", text: /manage your hosted events/i
  end

  private

  def sign_in(user)
    user.generate_magic_link_token!
    get verify_magic_link_path, params: { token: user.magic_link_token }
  end
end
