require "test_helper"

class Ai::EventScoutTest < ActiveSupport::TestCase
  setup do
    @orig = ENV["OPENROUTER_API_KEY"]
    ENV["OPENROUTER_API_KEY"] = "sk-test"
  end

  teardown { ENV["OPENROUTER_API_KEY"] = @orig }

  def http_returning(events)
    content = { events: events }.to_json
    Module.new do
      define_singleton_method(:post) do |_uri, _body, _headers|
        Struct.new(:body).new({ "choices" => [ { "message" => { "content" => content } } ] }.to_json)
      end
    end
  end

  test "parses candidates and drops entries without a title or http source_url" do
    events = [
      { "title" => "Good", "description" => "d", "date" => "2026-06-20", "time" => nil, "location" => "X", "source_url" => "https://example.com/a", "organizer" => nil },
      { "title" => "No URL", "description" => "d", "date" => "2026-06-21", "time" => nil, "location" => "Y", "source_url" => "", "organizer" => nil },
      { "title" => "", "description" => "d", "date" => "2026-06-22", "time" => nil, "location" => "Z", "source_url" => "https://example.com/c", "organizer" => nil }
    ]
    result = Ai::EventScout.call(totem: totems(:city_board_totem), http_client: http_returning(events))
    assert result.ok
    assert_equal 1, result.candidates.size
    assert_equal "Good", result.candidates.first["title"]
  end

  test "returns not-ok when the client fails (e.g. missing key)" do
    ENV["OPENROUTER_API_KEY"] = nil
    result = Ai::EventScout.call(totem: totems(:city_board_totem))
    assert_not result.ok
  end
end
