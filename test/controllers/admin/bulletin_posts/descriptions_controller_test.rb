require "test_helper"

class Admin::BulletinPosts::DescriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
  end

  def sign_in_as_admin
    post admin_login_path, params: { email: @admin.email, password: "password123" }
  end

  test "summarize returns polished text as JSON for an admin" do
    sign_in_as_admin
    result = Ai::DescriptionAssistant::Result.new(ok: true, text: "Tidy one-liner", error: nil)
    Ai::DescriptionAssistant.stub :summarize, result do
      post admin_bulletin_post_description_summarize_path, params: { text: "a verbose description" }
    end
    assert_response :success
    assert_equal "Tidy one-liner", response.parsed_body["text"]
  end

  test "blank text returns 422" do
    sign_in_as_admin
    post admin_bulletin_post_description_summarize_path, params: { text: "  " }
    assert_response :unprocessable_entity
  end

  test "requires admin authentication" do
    post admin_bulletin_post_description_summarize_path, params: { text: "x" }
    assert_redirected_to admin_login_path
  end
end
