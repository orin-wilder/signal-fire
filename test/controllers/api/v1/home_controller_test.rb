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
end
