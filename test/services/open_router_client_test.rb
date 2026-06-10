require "test_helper"

class OpenRouterClientTest < ActiveSupport::TestCase
  OK_BODY = {
    "choices" => [ { "message" => { "content" => "hello" } } ]
  }.freeze

  FakeHTTP = Module.new do
    def self.post(_uri, _body, _headers)
      Struct.new(:body).new(OpenRouterClientTest::OK_BODY.to_json)
    end
  end

  ApiErrorHTTP = Module.new do
    def self.post(_uri, _body, _headers)
      Struct.new(:body).new({ "error" => { "message" => "rate limited" } }.to_json)
    end
  end

  RaisingHTTP = Module.new do
    def self.post(_uri, _body, _headers)
      raise SocketError, "connection refused"
    end
  end

  def with_key(value)
    original = ENV["OPENROUTER_API_KEY"]
    ENV["OPENROUTER_API_KEY"] = value
    yield
  ensure
    ENV["OPENROUTER_API_KEY"] = original
  end

  test "returns error when key is missing" do
    with_key(nil) do
      result = OpenRouterClient.chat(model: "m", messages: [], http_client: FakeHTTP)
      assert_not result.ok
      assert_equal "missing OPENROUTER_API_KEY", result.error
      assert_nil result.data
    end
  end

  test "returns ok result with parsed body on success" do
    with_key("sk-test") do
      result = OpenRouterClient.chat(model: "m", messages: [ { role: "user", content: "hi" } ], http_client: FakeHTTP)
      assert result.ok
      assert_nil result.error
      assert_equal "hello", result.data.dig("choices", 0, "message", "content")
    end
  end

  test "returns error result when the API responds with an error body" do
    with_key("sk-test") do
      result = OpenRouterClient.chat(model: "m", messages: [], http_client: ApiErrorHTTP)
      assert_not result.ok
      assert_match "rate limited", result.error
      assert_nil result.data
    end
  end

  test "returns error result on network failure" do
    with_key("sk-test") do
      result = OpenRouterClient.chat(model: "m", messages: [], http_client: RaisingHTTP)
      assert_not result.ok
      assert_match "connection refused", result.error
    end
  end
end
