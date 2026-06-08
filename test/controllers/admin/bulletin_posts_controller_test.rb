require "test_helper"

class Admin::BulletinPostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @totem = totems(:main_totem)
    @pending = @totem.bulletin_posts.create!(title: "Pickup soccer", starts_at: 3.days.from_now,
                                             description: "fields open", status: "pending",
                                             submitter_ip: "203.0.113.5")
  end

  # ── Auth guard ───────────────────────────────────────────────────────────

  test "redirects to login when not signed in" do
    get admin_bulletin_posts_path
    assert_redirected_to admin_login_path
  end

  test "redirects non-admin" do
    post host_login_path, params: { email: users(:host_user).email, password: "password123" }
    get admin_bulletin_posts_path
    assert_redirected_to admin_login_path
  end

  # ── Index ──────────────────────────────────────────────────────────────────

  test "lists only pending posts with totem, IP and scan count" do
    @totem.update_column(:bulletin_board_scan_count, 12)
    approved = @totem.bulletin_posts.create!(title: "Already live", starts_at: 2.days.from_now,
                                             description: "x", status: "approved")
    sign_in_as_admin
    get admin_bulletin_posts_path
    assert_response :success
    assert_select "td", text: /Pickup soccer/
    assert_select "td", text: /Already live/, count: 0
    assert_select "td", text: /203\.0\.113\.5/
    assert_select "p", text: /12 SCANS/
  end

  test "empty state when no pending" do
    @pending.destroy
    sign_in_as_admin
    get admin_bulletin_posts_path
    assert_response :success
    assert_select "p", text: /queue's clear/i
  end

  # ── Approve ──────────────────────────────────────────────────────────────

  test "approve flips status and redirects" do
    sign_in_as_admin
    patch approve_admin_bulletin_post_path(@pending)
    assert_equal "approved", @pending.reload.status
    assert_redirected_to admin_bulletin_posts_path
  end

  # ── Destroy ────────────────────────────────────────────────────────────────

  test "destroy removes the post" do
    sign_in_as_admin
    assert_difference "BulletinPost.count", -1 do
      delete admin_bulletin_post_path(@pending)
    end
    assert_redirected_to admin_bulletin_posts_path
  end

  private

  def sign_in_as_admin
    post admin_login_path, params: { email: @admin.email, password: "password123" }
  end
end
