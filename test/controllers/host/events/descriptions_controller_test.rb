require "test_helper"

class Host::Events::DescriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = users(:host_user)
    post host_login_path, params: { email: @host.email, password: "password123" }
  end

  def ok_result(text)
    Ai::DescriptionAssistant::Result.new(ok: true, text: text, error: nil)
  end

  test "enhance returns rewritten text as JSON" do
    Ai::DescriptionAssistant.stub :enhance, ok_result("Polished copy") do
      post host_event_description_enhance_path, params: { text: "rough copy" }
    end
    assert_response :success
    assert_equal "Polished copy", response.parsed_body["text"]
  end

  test "summarize returns short text as JSON" do
    Ai::DescriptionAssistant.stub :summarize, ok_result("Short blurb") do
      post host_event_description_summarize_path, params: { text: "a long description" }
    end
    assert_response :success
    assert_equal "Short blurb", response.parsed_body["text"]
  end

  test "blank text returns 422 and does not call the service" do
    # No stub: if the service were called it would try a real request; blank
    # text must short-circuit before that.
    post host_event_description_enhance_path, params: { text: "   " }
    assert_response :unprocessable_entity
    assert response.parsed_body["error"].present?
  end

  test "service failure returns 422" do
    fail_result = Ai::DescriptionAssistant::Result.new(ok: false, text: nil, error: "boom")
    Ai::DescriptionAssistant.stub :enhance, fail_result do
      post host_event_description_enhance_path, params: { text: "rough copy" }
    end
    assert_response :unprocessable_entity
  end

  test "requires host authentication" do
    delete host_logout_path
    post host_event_description_enhance_path, params: { text: "x" }
    assert_response :redirect
  end
end
