require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "GET /about renders about page" do
    get about_path
    assert_response :success
    assert_select "h1", text: /permission structure/i
  end

  test "get the app nav link hidden by default" do
    get about_path
    assert_select "a", text: /Get the app/i, count: 0
  end

  test "get the app nav link is gone even when APP_NUDGES_ENABLED=true" do
    ENV["APP_NUDGES_ENABLED"] = "true"
    get about_path
    assert_select "a", text: /Get the app/i, count: 0
  ensure
    ENV.delete("APP_NUDGES_ENABLED")
  end

  test "GET /host-with-us returns 200" do
    get host_inquiry_path
    assert_response :success
  end

  test "host inquiry page fires analytics event" do
    tracked = []
    AnalyticsService.stub(:track, ->(name, **props) { tracked << [name, props] }) do
      get host_inquiry_path
    end
    assert_includes tracked.map(&:first), "host_inquiry_viewed"
  end

  test "host inquiry mailto link contains all four structured body fields" do
    get host_inquiry_path
    assert_match "Location%3A", response.body
    assert_match "Frequency%3A", response.body
    assert_match "Regulars%3A", response.body
    assert_match "coordinate%3A", response.body
  end
end
