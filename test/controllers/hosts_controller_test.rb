require "test_helper"

class HostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @profile = host_profiles(:active_profile)
    @host    = @profile.user
  end

  # ── 200 / 404 ─────────────────────────────────────────────────────────────

  test "GET /h/:slug returns 200 for active host" do
    get host_page_path(@profile.slug)
    assert_response :success
  end

  test "GET /h/:slug returns 404 for unknown slug" do
    get host_page_path("does-not-exist")
    assert_response :not_found
  end

  test "GET /h/:slug returns 404 for deactivated host" do
    deactivated = host_profiles(:deactivated_profile)
    get host_page_path(deactivated.slug)
    assert_response :not_found
  end

  # ── Story panel ───────────────────────────────────────────────────────────

  test "story panel renders when host_story is present" do
    @profile.update!(host_story: "Started Sunday jams three years ago.")
    get host_page_path(@profile.slug)
    assert_response :success
    assert_select "p", text: /Started Sunday jams three years ago/
    assert_select "p", text: /Meet your host/i
  end

  test "story panel is absent when host_story is blank" do
    @profile.update!(host_story: nil)
    get host_page_path(@profile.slug)
    assert_response :success
    assert_select "p", text: /Meet your host/i, count: 0
  end

  # ── No auth required ──────────────────────────────────────────────────────

  test "page is publicly accessible without sign-in" do
    get host_page_path(@profile.slug)
    assert_response :success
  end

  # ── Visibility gate (publicly_visible) ─────────────────────────────────────

  # e.g. a scouted event assigned to this host but not yet approved must not
  # appear on their public profile.
  test "pending_review events are hidden from the host page" do
    totems(:main_totem).events.create!(
      title: "Unreviewed Scouted Event",
      host_user: @host,
      start_time: 1.day.from_now,
      end_time: 1.day.from_now + 2.hours,
      status: "active",
      provenance: "scouted",
      approval_state: "pending_review",
      source_url: "https://example.com/source"
    )
    get host_page_path(@profile.slug)
    assert_response :success
    assert_no_match(/Unreviewed Scouted Event/, response.body)
  end
end
