require "test_helper"

class Auth::Admin::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "GET /admin/login renders login form" do
    get admin_login_path
    assert_response :success
  end

  test "POST /admin/login signs in admin with correct credentials" do
    post admin_login_path, params: { email: "admin@example.com", password: "password123" }
    assert_equal users(:admin_user).id, session[:user_id]
  end

  test "POST /admin/login is case-insensitive on email" do
    post admin_login_path, params: { email: "ADMIN@EXAMPLE.COM", password: "password123" }
    assert_equal users(:admin_user).id, session[:user_id]
  end

  test "POST /admin/login rejects wrong password" do
    post admin_login_path, params: { email: "admin@example.com", password: "wrongpassword" }
    assert_nil session[:user_id]
    assert_response :unprocessable_entity
  end

  test "POST /admin/login rejects non-admin user" do
    post admin_login_path, params: { email: "host@example.com", password: "password123" }
    assert_nil session[:user_id]
    assert_response :unprocessable_entity
  end

  test "POST /admin/login rejects unknown email" do
    post admin_login_path, params: { email: "nobody@example.com", password: "password123" }
    assert_nil session[:user_id]
    assert_response :unprocessable_entity
  end

  test "DELETE /admin/logout clears session and redirects to login" do
    post admin_login_path, params: { email: "admin@example.com", password: "password123" }
    delete admin_logout_path
    assert_nil session[:user_id]
    assert_redirected_to admin_login_path
  end

  # Rate limiting (cache-backed; swap the null_store for a real one)
  test "POST /admin/login is rate limited per IP after 10 attempts" do
    store = ActiveSupport::Cache::MemoryStore.new
    Rails.stub(:cache, store) do
      10.times do
        post admin_login_path, params: { email: "admin@example.com", password: "wrongpassword" }
        assert_response :unprocessable_entity
      end
      post admin_login_path, params: { email: "admin@example.com", password: "wrongpassword" }
      assert_redirected_to admin_login_path
      assert_match(/too many attempts/i, flash[:alert])
    end
  end
end
