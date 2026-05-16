require "test_helper"

class Host::InsightsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = users(:host_user)
    @past_event = events(:past_event)
    @upcoming_event = events(:upcoming_event)

    # Create a check-in for the past event so stat cards and chart have data
    @check_in = CheckIn.create!(
      user: users(:regular_user),
      event: @past_event,
      checked_in_at: @past_event.start_time + 5.minutes
    )

    # Record regular_user as a first-timer for this host
    @first_seen = UserHostFirstSeen.create!(
      user: users(:regular_user),
      host_user: @host,
      first_seen_at: @check_in.checked_in_at
    )

    post host_login_path, params: { email: @host.email, password: "password123" }
  end

  # ── Auth ────────────────────────────────────────────────────────────

  test "redirects unauthenticated request to login" do
    delete host_logout_path
    get host_insights_path(event_slug: @past_event.slug)
    assert_redirected_to host_login_path
  end

  # ── 200 / correct event ─────────────────────────────────────────────

  test "returns 200 for a past event belonging to the signed-in host" do
    get host_insights_path(event_slug: @past_event.slug)
    assert_response :success
  end

  test "renders event title and date in eyebrow" do
    get host_insights_path(event_slug: @past_event.slug)
    assert_match @past_event.title, response.body
    assert_match @past_event.start_time.strftime("%b %-d"), response.body
  end

  test "renders headline with event day" do
    get host_insights_path(event_slug: @past_event.slug)
    assert_select "h1", text: /A look at last #{@past_event.start_time.strftime("%A")}/i
  end

  test "renders all four stat card labels" do
    get host_insights_path(event_slug: @past_event.slug)
    assert_match "Total check-ins", response.body
    assert_match "Authenticated", response.body
    assert_match "Anonymous web", response.body
    assert_match "Followers", response.body
  end

  test "stat cards reflect check-in data" do
    get host_insights_path(event_slug: @past_event.slug)
    assert_response :success
    # 1 total (authenticated) check-in, 0 anonymous
    assert_select "p.font-mono", text: "1"
    assert_select "p.font-mono", text: "0"
  end

  # ── 404 cases ───────────────────────────────────────────────────────

  test "returns 404 for an event that has not yet ended" do
    get host_insights_path(event_slug: @upcoming_event.slug)
    assert_response :not_found
  end

  test "returns 404 for an unknown event slug" do
    get host_insights_path(event_slug: "no-such-event")
    assert_response :not_found
  end

  # ── Privacy: first names only ────────────────────────────────────────

  test "attendee list shows only first name, not full name" do
    get host_insights_path(event_slug: @past_event.slug)
    assert_response :success
    # "Regular User" → should appear as "Regular" only
    assert_no_match "Regular User", response.body
    assert_match "Regular", response.body
  end

  # ── Chart ────────────────────────────────────────────────────────────

  test "renders SVG bar chart when check-ins exist" do
    get host_insights_path(event_slug: @past_event.slug)
    assert_select "svg"
  end

  test "peak bar uses ember color" do
    get host_insights_path(event_slug: @past_event.slug)
    assert_match "#DA5520", response.body
  end

  # ── Dashboard link ───────────────────────────────────────────────────

  test "dashboard shows View Insights link for past events" do
    get host_dashboard_path
    assert_select "a", text: "View Insights →"
  end

  test "dashboard shows Edit link for upcoming events" do
    get host_dashboard_path
    assert_select "a[href='#{edit_host_event_path(@upcoming_event)}']"
  end
end
