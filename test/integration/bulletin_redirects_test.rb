require "test_helper"

# The retired Bulletin Board URLs 301-redirect into the unified totem/city boards
# so printed QR codes and old links keep working.
class BulletinRedirectsTest < ActionDispatch::IntegrationTest
  test "old /board/:slug 301-redirects to the totem board" do
    get "/board/#{totems(:main_totem).slug}"
    assert_response :moved_permanently
    assert_redirected_to "/t/#{totems(:main_totem).slug}"
  end

  test "old /stpeteboards 301-redirects to the city board" do
    get "/stpeteboards"
    assert_response :moved_permanently
    assert_redirected_to "/stpete"
  end
end
