require "test_helper"

class AnalyticsRecordingTest < ActionDispatch::IntegrationTest
  setup do
    @totem = totems(:main_totem)
    @event = events(:upcoming_event)
  end

  test "scanning a short code records a totem_scan" do
    assert_difference -> { AnalyticsEvent.named("totem_scan").count }, 1 do
      get totem_short_code_path(@totem.short_code)
    end
    record = AnalyticsEvent.named("totem_scan").last
    assert_equal @totem.id, record.totem_id
    assert_equal "short_code", record.source
    assert record.visitor_hash.present?
  end

  test "viewing a board records a board_view" do
    assert_difference -> { AnalyticsEvent.named("board_view").count }, 1 do
      get totem_board_path(@totem.slug)
    end
    assert_equal "qr_scan", AnalyticsEvent.named("board_view").last.source
  end

  test "viewing an event records an event_view" do
    assert_difference -> { AnalyticsEvent.named("event_view").count }, 1 do
      get totem_event_path(@event.totem.slug, @event.slug)
    end
    record = AnalyticsEvent.named("event_view").last
    assert_equal @event.id, record.event_id
  end

  test "saving to calendar records a calendar_add" do
    assert_difference -> { AnalyticsEvent.named("calendar_add").count }, 1 do
      get event_calendar_path(@event.totem.slug, @event.slug, format: :ics)
    end
    assert_equal @event.id, AnalyticsEvent.named("calendar_add").last.event_id
  end

  test "a share via the analytics proxy records an event_share" do
    assert_difference -> { AnalyticsEvent.named("event_share").count }, 1 do
      post analytics_track_path, params: { event: "event_shared", event_id: @event.id }
    end
    record = AnalyticsEvent.named("event_share").last
    assert_equal @event.id, record.event_id
    assert_equal @event.totem_id, record.totem_id
  end

  test "a non-share analytics ping records nothing in analytics_events" do
    assert_no_difference -> { AnalyticsEvent.count } do
      post analytics_track_path, params: { event: "something_else", event_id: @event.id }
    end
  end

  test "the visitor hash is stable within a request series and never sets a cookie" do
    get totem_board_path(@totem.slug)
    first = AnalyticsEvent.named("board_view").last.visitor_hash
    get totem_board_path(@totem.slug)
    second = AnalyticsEvent.named("board_view").last.visitor_hash
    assert_equal first, second, "same client should hash identically on the same day"
    assert_no_match(/visitor/i, response.headers["Set-Cookie"].to_s)
  end
end
