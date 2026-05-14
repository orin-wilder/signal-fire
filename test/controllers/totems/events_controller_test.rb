require "test_helper"

class Totems::EventsControllerTest < ActionDispatch::IntegrationTest
  test "GET /t/:slug/e/:event_slug renders event detail" do
    event = events(:upcoming_event)
    get totem_event_path(event.totem.slug, event.slug)
    assert_response :success
    assert_select "h1", text: /#{event.title}/
  end

  test "GET /t/:slug/e/:event_slug shows cancelled banner for cancelled event" do
    event = events(:cancelled_event)
    get totem_event_path(event.totem.slug, event.slug)
    assert_response :success
    assert_select "[role='alert']", text: /cancelled/i
  end

  test "GET /t/:slug/e/:event_slug 404 for unknown event slug" do
    get totem_event_path(totems(:main_totem).slug, "no-such-event")
    assert_response :not_found
  end

  test "GET /t/:slug/e/:event_slug 404 when event belongs to different totem" do
    event = events(:upcoming_event)
    get totem_event_path(totems(:secondary_totem).slug, event.slug)
    assert_response :not_found
  end

  test "check-in button visible for active_now event" do
    event = events(:active_now_event)
    get totem_event_path(event.totem.slug, event.slug)
    assert_response :success
    assert_select "input[value='Check in']"
  end

  test "check-in button hidden for upcoming event" do
    event = events(:upcoming_event)
    get totem_event_path(event.totem.slug, event.slug)
    assert_response :success
    assert_select "input[value='Check in']", count: 0
  end

  test "app nudge button and sheet are hidden by default (APP_NUDGES_ENABLED unset)" do
    event = events(:upcoming_event)
    get totem_event_path(event.totem.slug, event.slug)
    assert_select "button", text: /Follow in the app/, count: 0
    assert_select "h2", text: /works better in the app/, count: 0
  end

  test "app nudge button and sheet are shown when APP_NUDGES_ENABLED=true" do
    ENV["APP_NUDGES_ENABLED"] = "true"
    event = events(:upcoming_event)
    get totem_event_path(event.totem.slug, event.slug)
    assert_select "button", text: /Follow in the app/
    assert_select "h2", text: /works better in the app/
  ensure
    ENV.delete("APP_NUDGES_ENABLED")
  end

  test "app nudge button hidden for cancelled event even when APP_NUDGES_ENABLED=true" do
    ENV["APP_NUDGES_ENABLED"] = "true"
    event = events(:cancelled_event)
    get totem_event_path(event.totem.slug, event.slug)
    assert_select "button", text: /Follow in the app/, count: 0
  ensure
    ENV.delete("APP_NUDGES_ENABLED")
  end

  test "tracks event_detail_viewed with event_id, totem_id and auth_state" do
    event = events(:upcoming_event)
    tracked = []
    AnalyticsService.stub(:track, ->(name, **props) { tracked << [name, props] }) do
      get totem_event_path(event.totem.slug, event.slug)
    end
    assert_equal 1, tracked.size
    assert_equal "event_detail_viewed", tracked.first[0]
    assert_equal event.id,        tracked.first[1][:event_id]
    assert_equal event.totem_id,  tracked.first[1][:totem_id]
    assert_equal :anonymous,      tracked.first[1][:auth_state]
  end

  # ── Calendar export ────────────────────────────────────────────────────────

  test "GET /t/:slug/e/:event_slug/calendar.ics returns text/calendar" do
    event = events(:upcoming_event)
    get event_calendar_path(event.totem.slug, event.slug)
    assert_response :success
    assert_includes response.content_type, "text/calendar"
    assert_includes response.body, "BEGIN:VCALENDAR"
    assert_includes response.body, "SUMMARY:#{event.title}"
  end

  test "calendar.ics includes RRULE for recurring event" do
    event = events(:weekly_event)
    get event_calendar_path(event.totem.slug, event.slug)
    assert_response :success
    assert_includes response.body, "RRULE:#{event.recurrence_rule}"
  end

  test "calendar.ics has no RRULE for one-time event" do
    event = events(:upcoming_event)
    get event_calendar_path(event.totem.slug, event.slug)
    refute_includes response.body, "RRULE:"
  end

  test "calendar.ics returns 404 for unknown event slug" do
    get event_calendar_path(totems(:main_totem).slug, "no-such-event")
    assert_response :not_found
  end

  test "GET /t/:slug/e/:event_slug shows calendar and share buttons" do
    event = events(:upcoming_event)
    get totem_event_path(event.totem.slug, event.slug)
    assert_response :success
    assert_select "a[href*='calendar.ics']", text: /Save to my calendar/
    assert_select "button[data-controller='share']", text: /Share this event/
  end

  test "GET /t/:slug/e/:event_slug shows Follow host row" do
    event = events(:upcoming_event)
    get totem_event_path(event.totem.slug, event.slug)
    assert_response :success
    assert_select "p", text: /HOST/i
  end
end
