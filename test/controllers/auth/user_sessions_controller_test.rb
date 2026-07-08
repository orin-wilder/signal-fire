require "test_helper"

class Auth::UserSessionsControllerTest < ActionDispatch::IntegrationTest
  test "GET /sign_in renders sign in page with password form" do
    get sign_in_path
    assert_response :success
    assert_select "h1", text: /Sign in/i
    assert_select "input[type='password']"
  end

  test "GET /sign_in/magic_link renders magic link page" do
    get sign_in_magic_link_path
    assert_response :success
    assert_select "input[type='password']", count: 0
  end

  # --- Password flow ---

  test "POST /sign_in with correct password signs user in and redirects to about when no return_to" do
    user = users(:regular_user)
    post sign_in_path, params: { email: user.email, password: "password123" }
    assert_redirected_to about_path
    assert_equal user.id, session[:user_id]
  end

  test "POST /sign_in with correct password redirects back to totem board when return_to is stored" do
    totem = totems(:main_totem)
    get totem_board_path(totem.slug)  # stores return_to in session
    user = users(:regular_user)
    post sign_in_path, params: { email: user.email, password: "password123" }
    assert_redirected_to totem_board_path(totem.slug)
  end

  test "POST /sign_in with wrong password re-renders with alert" do
    user = users(:regular_user)
    post sign_in_path, params: { email: user.email, password: "wrongpassword" }
    assert_response :unprocessable_entity
    assert_select "[role='alert']", text: /invalid email or password/i
    assert_nil session[:user_id]
  end

  test "POST /sign_in with unknown email and password re-renders with alert" do
    post sign_in_path, params: { email: "nobody@example.com", password: "secret123" }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
  end

  # --- Magic link flow ---

  test "POST /sign_in without password sends magic link for known email" do
    user = users(:regular_user)
    assert_enqueued_jobs 1, only: ActionMailer::MailDeliveryJob do
      post sign_in_path, params: { email: user.email }
    end
    assert_redirected_to sign_in_magic_link_path
    assert_match /sent you a sign-in link/i, flash[:notice]
  end

  test "POST /sign_in without password shows same success for unknown email" do
    assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
      post sign_in_path, params: { email: "nobody@example.com" }
    end
    assert_redirected_to sign_in_magic_link_path
    assert_match /sent you a sign-in link/i, flash[:notice]
  end

  # --- Rate limiting (cache-backed; swap the null_store for a real one) ---

  test "POST /sign_in is rate limited per IP after 10 attempts" do
    store = ActiveSupport::Cache::MemoryStore.new
    Rails.stub(:cache, store) do
      10.times do
        post sign_in_path, params: { email: "nobody@example.com", password: "wrong" }
        assert_response :unprocessable_entity
      end
      post sign_in_path, params: { email: "nobody@example.com", password: "wrong" }
      assert_redirected_to sign_in_path
      assert_match(/too many attempts/i, flash[:alert])
    end
  end

  test "rate limit fails open when the cache backend raises" do
    failing_cache = Class.new do
      def increment(*, **) = raise(ActiveRecord::StatementInvalid, "cache down")
    end.new
    user = users(:regular_user)
    Rails.stub(:cache, failing_cache) do
      post sign_in_path, params: { email: user.email, password: "password123" }
      assert_redirected_to about_path
    end
  end

  # --- Sign out ---

  test "DELETE /sign_out clears session and redirects" do
    user = users(:regular_user)
    user.generate_magic_link_token!
    get verify_magic_link_path, params: { token: user.magic_link_token }
    assert_equal user.id, session[:user_id]

    delete sign_out_path
    assert_redirected_to root_path
    assert_nil session[:user_id]
  end
end
