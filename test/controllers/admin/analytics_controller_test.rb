require "test_helper"

class Admin::AnalyticsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @totem = totems(:main_totem)
    @event = events(:upcoming_event)
  end

  test "redirects to login when not signed in" do
    get admin_analytics_path
    assert_redirected_to admin_login_path
  end

  test "renders the analytics dashboard for an admin" do
    seed_events
    sign_in_as_admin
    get admin_analytics_path
    assert_response :success
    assert_select "h1", text: /analytics/i
    assert_select "h2", text: /by totem/i
    assert_select "h2", text: /by activity/i
  end

  test "defaults to a 30 day range and marks it active" do
    sign_in_as_admin
    get admin_analytics_path
    assert_response :success
    assert_select "a.bg-ink", text: "30d"
  end

  test "honours an allowed range and falls back for unsupported ones" do
    sign_in_as_admin

    get admin_analytics_path(range: 7)
    assert_select "a.bg-ink", text: "7d"

    get admin_analytics_path(range: 9999)
    assert_select "a.bg-ink", text: "30d"
  end

  test "lists totems and activities that have recorded events" do
    seed_events
    sign_in_as_admin
    get admin_analytics_path
    assert_response :success
    assert_select "td", text: @totem.name
    assert_select "td", text: @event.title
  end

  test "shows submission count and board-to-submission conversion" do
    seed_events
    sign_in_as_admin
    get admin_analytics_path
    assert_response :success
    # Overview cards include Submissions and the conversion rate.
    assert_select "p", text: "Submissions"
    assert_select "p", text: "Board → submission"
    # 1 submission / 4 board views = 25.0% platform conversion.
    assert_select "p", text: "25.0%"
    # Per-totem table carries the Conv. column.
    assert_select "th", text: "Conv."
  end

  test "shows empty states when there is no activity" do
    AnalyticsEvent.delete_all
    CheckIn.delete_all
    sign_in_as_admin
    get admin_analytics_path
    assert_response :success
    assert_select "p", text: /No totem activity/i
    assert_select "p", text: /No activity-level events/i
  end

  private

  def seed_events
    AnalyticsEvent.create!(name: "totem_scan", totem_id: @totem.id, source: "short_code",
      visitor_hash: "a", occurred_at: 1.day.ago)
    AnalyticsEvent.create!(name: "totem_scan", totem_id: @totem.id, source: "qr_scan",
      visitor_hash: "b", occurred_at: 2.days.ago)
    AnalyticsEvent.create!(name: "event_view", totem_id: @totem.id, event_id: @event.id,
      visitor_hash: "a", occurred_at: 1.day.ago)
    AnalyticsEvent.create!(name: "calendar_add", totem_id: @totem.id, event_id: @event.id,
      visitor_hash: "a", occurred_at: 1.day.ago)
    # 4 board views and 1 submission → 25% conversion.
    4.times do |i|
      AnalyticsEvent.create!(name: "board_view", totem_id: @totem.id,
        visitor_hash: "v#{i}", occurred_at: 1.day.ago)
    end
    AnalyticsEvent.create!(name: "event_submission", totem_id: @totem.id, event_id: @event.id,
      source: "pending_review", visitor_hash: "a", occurred_at: 1.day.ago)
  end

  def sign_in_as_admin
    post admin_login_path, params: { email: @admin.email, password: "password123" }
  end
end
