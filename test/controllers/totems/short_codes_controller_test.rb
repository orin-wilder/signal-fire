require "test_helper"

# Phase 6 — typed-entry short code. /g/:code resolves to a totem and 301s to its
# canonical board, tagged source=short_code for analytics.
class Totems::ShortCodesControllerTest < ActionDispatch::IntegrationTest
  test "GET /g/:code 301-redirects to the totem board with source=short_code" do
    totem = totems(:main_totem)
    get "/g/#{totem.short_code}"
    assert_response :moved_permanently
    assert_redirected_to totem_board_path(totem.slug, source: :short_code)
  end

  test "GET /g/:code 404 for an unknown code" do
    get "/g/9999"
    assert_response :not_found
  end
end
