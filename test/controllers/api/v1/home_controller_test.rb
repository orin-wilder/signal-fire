require "test_helper"

class Api::V1::HomeControllerTest < ActionDispatch::IntegrationTest
  test "GET /api/v1/home returns three-section structure" do
    get api_v1_home_path, as: :json, headers: auth_header(users(:follower_user))

    assert_response :success
    sections = response.parsed_body["sections"]
    assert sections.key?("yours")
    assert sections.key?("st_pete")
    assert sections.key?("nearby")
  end

  test "yours section is visible when user has favorites or follows" do
    get api_v1_home_path, as: :json, headers: auth_header(users(:follower_user))

    yours = response.parsed_body["sections"]["yours"]
    assert yours["visible"]
    assert yours.key?("items")
  end

  test "yours section is not visible when user has no favorites or follows" do
    get api_v1_home_path, as: :json, headers: auth_header(users(:regular_user))

    yours = response.parsed_body["sections"]["yours"]
    assert_equal false, yours["visible"]
    assert_not yours.key?("items")
  end

  test "st_pete section is always visible" do
    get api_v1_home_path, as: :json, headers: auth_header(users(:follower_user))

    st_pete = response.parsed_body["sections"]["st_pete"]
    assert st_pete["visible"]
    assert st_pete.key?("totems")
  end

  test "nearby section is always hidden in v1.5" do
    get api_v1_home_path, as: :json, headers: auth_header(users(:follower_user))

    nearby = response.parsed_body["sections"]["nearby"]
    assert_equal false, nearby["visible"]
  end

  test "returns 401 without token" do
    get api_v1_home_path, as: :json
    assert_response :unauthorized
  end

  # ── Visibility gate (publicly_visible) ─────────────────────────────────────

  # follower_user favorites main_totem; the soonest event there is
  # upcoming_event ("Morning Run", 1h out). A pending submission starting
  # sooner must not displace it.
  test "yours totem_favorite next_event skips pending_review events" do
    totems(:main_totem).events.create!(
      title: "Pending Submission",
      start_time: 45.minutes.from_now,
      status: "active",
      provenance: "board_submission",
      approval_state: "pending_review"
    )

    get api_v1_home_path, as: :json, headers: auth_header(users(:follower_user))

    item = response.parsed_body["sections"]["yours"]["items"]
      .find { |i| i["type"] == "totem_favorite" }
    assert_equal events(:upcoming_event).title, item.dig("next_event", "title")
  end

  test "yours host_follow next_event skips pending_review events" do
    totems(:main_totem).events.create!(
      title: "Unreviewed Scouted Event",
      host_user: users(:host_user),
      start_time: 45.minutes.from_now,
      end_time: 2.hours.from_now,
      status: "active",
      provenance: "scouted",
      approval_state: "pending_review",
      source_url: "https://example.com/source"
    )

    get api_v1_home_path, as: :json, headers: auth_header(users(:subscriber_user))

    item = response.parsed_body["sections"]["yours"]["items"]
      .find { |i| i["type"] == "host_follow" }
    assert_equal events(:upcoming_event).title, item.dig("next_event", "title")
  end

  test "st_pete section next_event skips pending_review events" do
    totems(:city_board_totem).events.create!(
      title: "Pending Submission",
      start_time: 1.day.from_now,
      status: "active",
      provenance: "board_submission",
      approval_state: "pending_review"
    )

    get api_v1_home_path, as: :json, headers: auth_header(users(:follower_user))

    totem_entry = response.parsed_body["sections"]["st_pete"]["totems"]
      .find { |t| t["slug"] == totems(:city_board_totem).slug }
    assert_not_equal "Pending Submission", totem_entry.dig("next_event", "title")
    assert_equal false, totem_entry["active_now"]
  end
end
