require "test_helper"

class CitiesControllerTest < ActionDispatch::IntegrationTest
  test "GET /stpete returns 200" do
    get city_board_path
    assert_response :success
  end

  test "/ redirects to /stpete" do
    get root_path
    assert_redirected_to "/stpete"
  end

  test "city board renders totems with character_description" do
    get city_board_path
    assert_select "h2", text: /City Board Totem/
  end

  test "totems without character_description are excluded" do
    no_desc = totems(:main_totem)
    no_desc.update!(character_description: nil)

    get city_board_path
    assert_select "h2", text: /#{Regexp.escape(no_desc.name)}/, count: 0
  end

  test "quiet totem renders quiet copy when no upcoming events" do
    totem = totems(:city_board_totem)
    totem.events.active.each { |e| e.update!(status: :cancelled) }

    get city_board_path
    assert_response :success
    assert_match "Quiet this week", response.body
  end

  test "active-now totem renders LIVE NOW chip with ember treatment" do
    totem = totems(:city_board_totem)
    host  = users(:host_user)
    totem.hosts << host unless totem.hosts.include?(host)

    Event.create!(
      totem: totem,
      host_user: host,
      title: "Live Event",
      slug: "city-board-live-event",
      start_time: 10.minutes.ago,
      end_time: 50.minutes.from_now,
      status: :active
    )

    get city_board_path
    assert_match "Live now", response.body
  end
end
