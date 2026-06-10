require "test_helper"

class Ai::DescriptionAssistantTest < ActiveSupport::TestCase
  setup do
    @original_key = ENV["OPENROUTER_API_KEY"]
    ENV["OPENROUTER_API_KEY"] = "sk-test"
  end

  teardown do
    ENV["OPENROUTER_API_KEY"] = @original_key
  end

  def http_returning(content)
    Module.new do
      define_singleton_method(:post) do |_uri, _body, _headers|
        Struct.new(:body).new({ "choices" => [ { "message" => { "content" => content } } ] }.to_json)
      end
    end
  end

  test "enhance returns the rewritten text" do
    result = Ai::DescriptionAssistant.enhance(text: "come dance", http_client: http_returning("Come dance with neighbors!"))
    assert result.ok
    assert_equal "Come dance with neighbors!", result.text
  end

  test "summarize truncates to 160 chars even when the model overshoots" do
    long = "x" * 300
    result = Ai::DescriptionAssistant.summarize(text: "a long event description", http_client: http_returning(long))
    assert result.ok
    assert_operator result.text.length, :<=, 160
  end

  test "returns not-ok when the model returns empty content" do
    result = Ai::DescriptionAssistant.enhance(text: "hi", http_client: http_returning("   "))
    assert_not result.ok
    assert_equal "empty response", result.error
  end

  test "propagates client errors (e.g. missing key)" do
    ENV["OPENROUTER_API_KEY"] = nil
    result = Ai::DescriptionAssistant.enhance(text: "hi")
    assert_not result.ok
    assert_equal "missing OPENROUTER_API_KEY", result.error
  end
end
