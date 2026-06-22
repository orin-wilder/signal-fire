require "test_helper"

class Totems::BoardsControllerTest < ActionDispatch::IntegrationTest
  test "GET /t/:slug renders show for active totem with events" do
    get totem_board_path(totems(:main_totem).slug)
    assert_response :success
  end

  test "GET /t/:slug renders empty for inactive totem" do
    get totem_board_path(totems(:inactive_totem).slug)
    assert_response :success
    assert_select "h1", text: /#{totems(:inactive_totem).name}/
  end

  test "GET /t/:slug renders empty for active totem with no events" do
    get totem_board_path(totems(:secondary_totem).slug)
    assert_response :success
    assert_select "form[action='#{empty_totem_email_captures_path}']"
  end

  test "board shows the inline add-event submission form and CTA" do
    totem = totems(:main_totem)
    get totem_board_path(totem.slug)
    assert_response :success
    assert_select "form[action='#{totem_event_submissions_path(totem.slug)}']"
    assert_select "button", text: /add an event here/i
  end

  test "submission form and CTA also render on an empty board" do
    totem = totems(:secondary_totem)
    get totem_board_path(totem.slug)
    assert_select "form[action='#{totem_event_submissions_path(totem.slug)}']"
    assert_select "button", text: /add an event here/i
  end

  # Regression: the photo shortcut used capture="environment", which forced the
  # camera open. It should be a plain image upload (photo library + files).
  test "photo upload input is a library/file picker, not a forced camera" do
    get totem_board_path(totems(:main_totem).slug)
    assert_response :success
    assert_select "input[type=file][accept='image/*']"
    assert_select "input[type=file][capture]", count: 0
  end

  test "board renders an Earlier section for recent past events" do
    # past_event fixture (one-time, published, ended 2h ago) belongs to main_totem.
    get totem_board_path(totems(:main_totem).slug)
    assert_response :success
    assert_select "h2", text: /Earlier/
    assert_match events(:past_event).title, response.body
  end

  test "empty board shows the AI scout CTA to a moderator" do
    post sign_in_path, params: { email: users(:admin_user).email, password: "password123" }
    get totem_board_path(totems(:secondary_totem).slug)
    assert_response :success
    assert_select "a", text: /find events with ai/i
  end

  test "empty board hides the AI scout CTA from anonymous visitors" do
    get totem_board_path(totems(:secondary_totem).slug)
    assert_select "a", text: /find events with ai/i, count: 0
  end

  test "GET /t/:slug 404 for unknown slug" do
    get totem_board_path("no-such-totem")
    assert_response :not_found
  end

  test "GET /t/:slug?dismiss_footer=1 sets cookie and redirects" do
    get totem_board_path(totems(:main_totem).slug, dismiss_footer: "1")
    assert_redirected_to totem_board_path(totems(:main_totem).slug)
    assert_equal "1", cookies[:footer_dismissed]
  end

  test "footer nudge is hidden when cookie is set" do
    cookies[:footer_dismissed] = "1"
    get totem_board_path(totems(:main_totem).slug)
    assert_response :success
    assert_select "[aria-label='Get app']", count: 0
  end

  test "app nudges are hidden by default (APP_NUDGES_ENABLED unset)" do
    get totem_board_path(totems(:main_totem).slug)
    assert_select "button", text: /Install/, count: 0
    assert_select "h2", text: /works better in the app/, count: 0
  end

  test "app nudges are hidden on empty board by default" do
    get totem_board_path(totems(:secondary_totem).slug)
    assert_select "h2", text: /works better in the app/, count: 0
  end

  # App-download nudges were removed (native app development is paused). They
  # must not render even with the legacy APP_NUDGES_ENABLED flag still set.
  test "app-download popup is never rendered even when APP_NUDGES_ENABLED=true" do
    ENV["APP_NUDGES_ENABLED"] = "true"
    get totem_board_path(totems(:main_totem).slug)
    assert_select "button", text: /Install/, count: 0
    assert_select "h2", text: /works better in the app/, count: 0
  ensure
    ENV.delete("APP_NUDGES_ENABLED")
  end

  test "app-download popup is absent on an empty board even when APP_NUDGES_ENABLED=true" do
    ENV["APP_NUDGES_ENABLED"] = "true"
    get totem_board_path(totems(:secondary_totem).slug)
    assert_select "h2", text: /works better in the app/, count: 0
  ensure
    ENV.delete("APP_NUDGES_ENABLED")
  end

  test "footer nudge hidden by cookie even when APP_NUDGES_ENABLED=true" do
    ENV["APP_NUDGES_ENABLED"] = "true"
    cookies[:footer_dismissed] = "1"
    get totem_board_path(totems(:main_totem).slug)
    assert_select "button", text: /Install/, count: 0
  ensure
    ENV.delete("APP_NUDGES_ENABLED")
  end

  test "account signup modal shown when nudges off and not signed in" do
    get totem_board_path(totems(:main_totem).slug)
    assert_select "h2", text: /Join Signal Fire/
    assert_select "[data-account-signup-target='modal']"
    assert_select "[data-account-signup-target='banner']"
  end

  test "account signup modal hidden when APP_NUDGES_ENABLED=true" do
    ENV["APP_NUDGES_ENABLED"] = "true"
    get totem_board_path(totems(:main_totem).slug)
    assert_select "[data-account-signup-target='modal']", count: 0
  ensure
    ENV.delete("APP_NUDGES_ENABLED")
  end

  test "account signup modal hidden when signed in" do
    user = users(:regular_user)
    user.generate_magic_link_token!
    get verify_magic_link_path, params: { token: user.magic_link_token }
    get totem_board_path(totems(:main_totem).slug)
    assert_select "[data-account-signup-target='modal']", count: 0
    assert_select "[data-account-signup-target='banner']", count: 0
  end

  test "account signup modal shown on empty board when nudges off" do
    get totem_board_path(totems(:secondary_totem).slug)
    assert_select "[data-account-signup-target='modal']"
    assert_select "[data-account-signup-target='banner']"
  end

  test "star toggle is hidden for unauthenticated users" do
    get totem_board_path(totems(:main_totem).slug)
    assert_select "button[data-controller='totem-favorite']", count: 0
  end

  test "star toggle is shown for authenticated users" do
    user = users(:regular_user)
    user.generate_magic_link_token!
    get verify_magic_link_path, params: { token: user.magic_link_token }

    get totem_board_path(totems(:main_totem).slug)
    assert_select "button[data-controller='totem-favorite']", count: 1
  end

  test "star toggle shows favorited state for user who has favorited the totem" do
    user = users(:follower_user)
    user.generate_magic_link_token!
    get verify_magic_link_path, params: { token: user.magic_link_token }

    get totem_board_path(totems(:main_totem).slug)
    assert_select "button[aria-pressed='true'][data-controller='totem-favorite']"
  end

  test "star toggle shows unfavorited state for user who has not favorited the totem" do
    user = users(:regular_user)
    user.generate_magic_link_token!
    get verify_magic_link_path, params: { token: user.magic_link_token }

    get totem_board_path(totems(:main_totem).slug)
    assert_select "button[aria-pressed='false'][data-controller='totem-favorite']"
  end

  test "tracks totem_board_viewed with totem_id and auth_state" do
    totem = totems(:main_totem)
    tracked = []
    AnalyticsService.stub(:track, ->(name, **props) { tracked << [name, props] }) do
      get totem_board_path(totem.slug)
    end
    assert_equal 1, tracked.size
    assert_equal "totem_board_viewed", tracked.first[0]
    assert_equal totem.id,   tracked.first[1][:totem_id]
    assert_equal :anonymous, tracked.first[1][:auth_state]
  end

  # ── Social proof (masthead) ─────────────────────────────────────────────────

  test "board shows host attribution when a primary host exists" do
    get totem_board_path(totems(:main_totem).slug)
    assert_select "p", text: /Hosted by/
  end

  test "board shows the weekly visitor count when there is recent traffic" do
    totem = totems(:main_totem)
    3.times do |i|
      AnalyticsEvent.create!(name: "board_view", totem_id: totem.id,
        visitor_hash: "v#{i}", occurred_at: 1.day.ago)
    end
    get totem_board_path(totem.slug)
    assert_select "span", text: /stopped by this week/
  end

  test "board hides activity stats when there is none" do
    # A totem with no analytics rows and no check-ins renders no stat row.
    AnalyticsEvent.where(totem_id: totems(:inactive_totem).id).delete_all
    get totem_board_path(totems(:inactive_totem).slug)
    assert_response :success
    assert_select "span", text: /stopped by this week/, count: 0
    assert_select "span", text: /check-in/, count: 0
  end
end
