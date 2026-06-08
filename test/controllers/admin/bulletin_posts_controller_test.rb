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

  test "index shows pending queue with totem, IP and scan count, and approved list" do
    @totem.update_column(:bulletin_board_scan_count, 12)
    @totem.bulletin_posts.create!(title: "Already live", starts_at: 2.days.from_now,
                                  description: "x", status: "approved")
    sign_in_as_admin
    get admin_bulletin_posts_path
    assert_response :success
    assert_select "td", text: /Pickup soccer/      # pending
    assert_select "td", text: /Already live/        # approved section
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

  test "approved empty state when none approved" do
    sign_in_as_admin
    get admin_bulletin_posts_path
    assert_response :success
    assert_select "p", text: /nothing approved yet/i
  end

  # ── Edit / Update ────────────────────────────────────────────────────────

  test "edit renders the form" do
    sign_in_as_admin
    get edit_admin_bulletin_post_path(@pending)
    assert_response :success
    assert_select "form"
    assert_select "input[name=?][value=?]", "bulletin_post[title]", "Pickup soccer"
  end

  test "update edits fields and recomposes starts_at in Eastern" do
    sign_in_as_admin
    patch admin_bulletin_post_path(@pending), params: {
      bulletin_post: {
        title: "Pickup basketball", date: "2030-11-15", time: "19:00",
        description: "courts open", recurring: "0"
      }
    }
    assert_redirected_to admin_bulletin_posts_path
    @pending.reload
    assert_equal "Pickup basketball", @pending.title
    assert_equal "courts open", @pending.description
    eastern = @pending.starts_at.in_time_zone("America/New_York")
    assert_equal "2030-11-15 19:00", eastern.strftime("%Y-%m-%d %H:%M")
  end

  test "update can set recurring with cadence" do
    sign_in_as_admin
    patch admin_bulletin_post_path(@pending), params: {
      bulletin_post: {
        title: @pending.title, date: "2030-11-15", time: "19:00",
        description: "x", recurring: "1", recurrence_cadence: "monthly"
      }
    }
    @pending.reload
    assert @pending.recurring?
    assert_equal "monthly", @pending.recurrence_cadence
  end

  test "update drops cadence when not recurring" do
    @pending.update!(recurring: true, recurrence_cadence: "weekly")
    sign_in_as_admin
    patch admin_bulletin_post_path(@pending), params: {
      bulletin_post: {
        title: @pending.title, date: "2030-11-15", time: "19:00",
        description: "x", recurring: "0", recurrence_cadence: "weekly"
      }
    }
    assert_nil @pending.reload.recurrence_cadence
  end

  test "update with blank title re-renders edit" do
    sign_in_as_admin
    patch admin_bulletin_post_path(@pending), params: {
      bulletin_post: { title: "", date: "2030-11-15", time: "19:00", description: "x", recurring: "0" }
    }
    assert_response :unprocessable_entity
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
