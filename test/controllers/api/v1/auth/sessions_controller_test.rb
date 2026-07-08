require "test_helper"

class Api::V1::Auth::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "POST /api/v1/auth/sign_in returns JWT for valid credentials" do
    post api_v1_auth_sign_in_path, params: {
      email: "host@example.com",
      password: "password123"
    }, as: :json

    assert_response :success
    body = response.parsed_body
    assert body["token"].present?
    assert_equal "host@example.com", body.dig("user", "email")
    assert_equal true, body.dig("user", "is_host")
  end

  test "POST /api/v1/auth/sign_in is case-insensitive on email" do
    post api_v1_auth_sign_in_path, params: {
      email: "HOST@EXAMPLE.COM",
      password: "password123"
    }, as: :json

    assert_response :success
    assert response.parsed_body["token"].present?
  end

  test "POST /api/v1/auth/sign_in returns 401 for wrong password" do
    post api_v1_auth_sign_in_path, params: {
      email: "host@example.com",
      password: "wrongpassword"
    }, as: :json

    assert_response :unauthorized
    assert response.parsed_body["error"].present?
  end

  test "POST /api/v1/auth/sign_in returns 401 for unknown email" do
    post api_v1_auth_sign_in_path, params: {
      email: "nobody@example.com",
      password: "password123"
    }, as: :json

    assert_response :unauthorized
  end

  test "DELETE /api/v1/auth/sign_out returns 204" do
    delete api_v1_auth_sign_out_path
    assert_response :no_content
  end

  test "returned JWT decodes to correct user" do
    post api_v1_auth_sign_in_path, params: {
      email: "host@example.com",
      password: "password123"
    }, as: :json

    token = response.parsed_body["token"]
    payload = JwtService.decode(token)
    assert_equal users(:host_user).id, payload[:user_id]
  end

  test "POST /api/v1/auth/sign_in identifies user with correct traits" do
    user = users(:host_user)
    identified = []
    AnalyticsService.stub(:identify, ->(id, **traits) { identified << [id, traits] }) do
      post api_v1_auth_sign_in_path, params: {
        email: user.email,
        password: "password123"
      }, as: :json
    end
    assert_equal 1, identified.size
    assert_equal user.id,          identified.first[0]
    assert_equal user.email,       identified.first[1][:email]
    assert_equal user.auth_method, identified.first[1][:auth_method]
    assert_equal user.is_host,     identified.first[1][:is_host]
  end

  # Rate limiting (cache-backed; swap the null_store for a real one)
  test "POST /api/v1/auth/sign_in returns 429 after 15 attempts" do
    store = ActiveSupport::Cache::MemoryStore.new
    Rails.stub(:cache, store) do
      15.times do
        post api_v1_auth_sign_in_path, params: { email: "nobody@example.com", password: "wrong" }, as: :json
        assert_response :unauthorized
      end
      post api_v1_auth_sign_in_path, params: { email: "nobody@example.com", password: "wrong" }, as: :json
      assert_response :too_many_requests
    end
  end

  test "POST /api/v1/auth/sign_in does not identify on failed sign-in" do
    identified = []
    AnalyticsService.stub(:identify, ->(id, **traits) { identified << [id, traits] }) do
      post api_v1_auth_sign_in_path, params: {
        email: "host@example.com",
        password: "wrongpassword"
      }, as: :json
    end
    assert_empty identified
  end
end
