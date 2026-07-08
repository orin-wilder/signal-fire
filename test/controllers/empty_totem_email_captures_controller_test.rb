require "test_helper"

class EmptyTotemEmailCapturesControllerTest < ActionDispatch::IntegrationTest
  test "POST with valid email creates record and redirects" do
    totem = totems(:secondary_totem)
    assert_difference "EmptyTotemEmailCapture.count", 1 do
      post empty_totem_email_captures_path, params: { totem_id: totem.id, email: "visitor@example.com" }
    end
    assert_redirected_to totem_board_path(totem.slug)
    assert flash[:notice].present?
  end

  test "repeat signup for the same totem reads as success without a second row" do
    totem = totems(:secondary_totem)
    post empty_totem_email_captures_path, params: { totem_id: totem.id, email: "visitor@example.com" }

    assert_no_difference "EmptyTotemEmailCapture.count" do
      post empty_totem_email_captures_path, params: { totem_id: totem.id, email: "visitor@example.com" }
    end
    assert_redirected_to totem_board_path(totem.slug)
    assert flash[:notice].present?
  end

  test "POST with invalid email redirects with alert" do
    totem = totems(:secondary_totem)
    assert_no_difference "EmptyTotemEmailCapture.count" do
      post empty_totem_email_captures_path, params: { totem_id: totem.id, email: "not-an-email" }
    end
    assert_redirected_to totem_board_path(totem.slug)
    assert flash[:alert].present?
  end

  test "POST with blank email redirects with alert" do
    totem = totems(:secondary_totem)
    assert_no_difference "EmptyTotemEmailCapture.count" do
      post empty_totem_email_captures_path, params: { totem_id: totem.id, email: "" }
    end
    assert_redirected_to totem_board_path(totem.slug)
    assert flash[:alert].present?
  end
end
