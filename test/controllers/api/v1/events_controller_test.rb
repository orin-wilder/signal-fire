require "test_helper"

class Api::V1::EventsControllerTest < ActionDispatch::IntegrationTest
  test "GET /api/v1/totems/:slug/events/:event_slug returns event detail" do
    event = events(:upcoming_event)
    get api_v1_totem_event_path(totem_slug: totems(:main_totem).slug, event_slug: event.slug),
        as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal event.title, body.dig("event", "title")
    assert_equal event.slug, body.dig("event", "slug")
    assert body["event"].key?("window_state")
    assert body["event"].key?("host")
  end

  test "returns 404 for unknown totem slug" do
    get api_v1_totem_event_path(totem_slug: "no-such-totem",
                                event_slug: events(:upcoming_event).slug), as: :json
    assert_response :not_found
  end

  test "returns 404 for unknown event slug" do
    get api_v1_totem_event_path(totem_slug: totems(:main_totem).slug,
                                event_slug: "no-such-event"), as: :json
    assert_response :not_found
  end

  test "user_checked_in is null when unauthenticated" do
    event = events(:upcoming_event)
    get api_v1_totem_event_path(totem_slug: totems(:main_totem).slug,
                                event_slug: event.slug), as: :json
    assert_nil response.parsed_body.dig("event", "user_checked_in")
  end

  test "user_checked_in is true when authenticated user has checked in" do
    event = events(:active_now_event)
    get api_v1_totem_event_path(totem_slug: totems(:main_totem).slug,
                                event_slug: event.slug), as: :json,
        headers: auth_header(users(:regular_user))
    assert_equal true, response.parsed_body.dig("event", "user_checked_in")
    assert response.parsed_body.dig("event", "checked_in_at").present?
  end

  test "following reflects host follow status" do
    event = events(:upcoming_event)
    get api_v1_totem_event_path(totem_slug: totems(:main_totem).slug,
                                event_slug: event.slug), as: :json,
        headers: auth_header(users(:subscriber_user))
    assert_equal true, response.parsed_body.dig("event", "following")
  end

  test "window_state is before for event starting in an hour" do
    event = events(:upcoming_event)
    get api_v1_totem_event_path(totem_slug: totems(:main_totem).slug,
                                event_slug: event.slug), as: :json
    assert_equal "before", response.parsed_body.dig("event", "window_state").to_s
  end

  test "window_state is happening_now for active_now event" do
    event = events(:active_now_event)
    get api_v1_totem_event_path(totem_slug: totems(:main_totem).slug,
                                event_slug: event.slug), as: :json
    assert_equal "happening_now", response.parsed_body.dig("event", "window_state").to_s
  end

  test "event response includes share_url and calendar_url" do
    event = events(:upcoming_event)
    get api_v1_totem_event_path(totem_slug: totems(:main_totem).slug,
                                event_slug: event.slug), as: :json
    assert_response :success
    body = response.parsed_body["event"]
    assert_includes body["share_url"],    "/t/#{event.totem.slug}/e/#{event.slug}"
    assert_includes body["calendar_url"], "/t/#{event.totem.slug}/e/#{event.slug}/calendar.ics"
  end

  test "event response includes recurrence_label for recurring event" do
    event = events(:weekly_event)
    get api_v1_totem_event_path(totem_slug: totems(:main_totem).slug,
                                event_slug: event.slug), as: :json
    assert_response :success
    assert response.parsed_body.dig("event", "recurrence_label").present?
  end
end
