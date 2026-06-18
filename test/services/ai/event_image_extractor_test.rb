require "test_helper"

class Ai::EventImageExtractorTest < ActiveSupport::TestCase
  DATA_URL = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQ".freeze

  setup do
    @orig = ENV["OPENROUTER_API_KEY"]
    ENV["OPENROUTER_API_KEY"] = "sk-test"
  end

  teardown { ENV["OPENROUTER_API_KEY"] = @orig }

  def http_returning(content)
    body = content.is_a?(String) ? content : content.to_json
    Module.new do
      define_singleton_method(:post) do |_uri, _body, _headers|
        Struct.new(:body).new({ "choices" => [ { "message" => { "content" => body } } ] }.to_json)
      end
    end
  end

  test "extracts the single-event fields from a vision response" do
    http = http_returning(
      "title" => "Sunset Yoga", "description" => "Flow at dusk",
      "date" => "2026-07-01", "time" => "18:00", "location" => "The Pier"
    )
    result = Ai::EventImageExtractor.call(image_data_url: DATA_URL, http_client: http)

    assert result.ok
    assert_equal "Sunset Yoga", result.event["title"]
    assert_equal "Flow at dusk", result.event["description"]
    assert_equal "2026-07-01", result.event["date"]
    assert_equal "18:00", result.event["time"]
    assert_equal "The Pier", result.event["location"]
  end

  test "returns only the known fields, dropping extras" do
    http = http_returning("title" => "X", "description" => nil, "date" => nil, "time" => nil, "location" => nil, "sneaky" => "y")
    result = Ai::EventImageExtractor.call(image_data_url: DATA_URL, http_client: http)
    assert result.ok
    assert_equal Ai::EventImageExtractor::FIELDS.sort, result.event.keys.sort
  end

  test "returns not-ok with a blank image" do
    assert_not Ai::EventImageExtractor.call(image_data_url: "").ok
  end

  test "returns not-ok when the client fails (missing key)" do
    ENV["OPENROUTER_API_KEY"] = nil
    assert_not Ai::EventImageExtractor.call(image_data_url: DATA_URL).ok
  end

  test "returns not-ok on unparseable content" do
    result = Ai::EventImageExtractor.call(image_data_url: DATA_URL, http_client: http_returning("not json"))
    assert_not result.ok
  end
end
