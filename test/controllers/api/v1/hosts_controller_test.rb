require "test_helper"

class Api::V1::HostsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @profile  = host_profiles(:active_profile)
    @host     = @profile.user
    @follower = users(:regular_user)
  end

  # ── Anonymous ─────────────────────────────────────────────────────────────

  test "GET /api/v1/hosts/:slug returns 200 without auth" do
    get "/api/v1/hosts/#{@profile.slug}", as: :json
    assert_response :success
  end

  test "returns host slug and display_name" do
    get "/api/v1/hosts/#{@profile.slug}", as: :json
    body = response.parsed_body
    assert_equal @profile.slug,         body.dig("host", "slug")
    assert_equal @profile.display_name, body.dig("host", "display_name")
  end

  test "returns following: false for anonymous request" do
    get "/api/v1/hosts/#{@profile.slug}", as: :json
    assert_equal false, response.parsed_body.dig("host", "following")
  end

  test "returns host_user_id" do
    get "/api/v1/hosts/#{@profile.slug}", as: :json
    assert_equal @host.id, response.parsed_body.dig("host", "host_user_id")
  end

  test "returns host_story in response" do
    @profile.update!(host_story: "Runs Sunday jams at the park.")
    get "/api/v1/hosts/#{@profile.slug}", as: :json
    assert_equal "Runs Sunday jams at the park.",
                 response.parsed_body.dig("host", "host_story")
  end

  test "returns nil host_story when blank" do
    @profile.update!(host_story: nil)
    get "/api/v1/hosts/#{@profile.slug}", as: :json
    assert_nil response.parsed_body.dig("host", "host_story")
  end

  test "returns upcoming_events array" do
    get "/api/v1/hosts/#{@profile.slug}", as: :json
    assert response.parsed_body.dig("host", "upcoming_events").is_a?(Array)
  end

  test "returns totems array" do
    get "/api/v1/hosts/#{@profile.slug}", as: :json
    assert response.parsed_body.dig("host", "totems").is_a?(Array)
  end

  test "returns 404 for unknown slug" do
    get "/api/v1/hosts/does-not-exist", as: :json
    assert_response :not_found
  end

  test "returns 404 for deactivated host" do
    deactivated = host_profiles(:deactivated_profile)
    get "/api/v1/hosts/#{deactivated.slug}", as: :json
    assert_response :not_found
  end

  # ── Authenticated ─────────────────────────────────────────────────────────

  test "returns following: false when authenticated user does not follow host" do
    get "/api/v1/hosts/#{@profile.slug}", as: :json,
        headers: auth_header(@follower)
    assert_equal false, response.parsed_body.dig("host", "following")
    assert_nil response.parsed_body.dig("host", "host_follow_id")
  end

  test "returns following: true when authenticated user follows host" do
    follow = HostFollow.create!(user: @follower, host_user: @host)
    get "/api/v1/hosts/#{@profile.slug}", as: :json,
        headers: auth_header(@follower)
    body = response.parsed_body
    assert_equal true,      body.dig("host", "following")
    assert_equal follow.id, body.dig("host", "host_follow_id")
  end

  # ── Visibility gate (publicly_visible) ─────────────────────────────────────

  test "pending_review events are excluded from upcoming_events" do
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
    get "/api/v1/hosts/#{@profile.slug}", as: :json
    titles = response.parsed_body.dig("host", "upcoming_events").map { |e| e["title"] }
    assert_not_includes titles, "Unreviewed Scouted Event"
  end
end
