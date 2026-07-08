require "test_helper"

class Totems::EventPhotoExtractionsControllerTest < ActionDispatch::IntegrationTest
  DATA_URL = "data:image/jpeg;base64,/9j/4AAQSkZJRg".freeze

  setup { @totem = totems(:main_totem) }

  def ok_result(event)
    Ai::EventImageExtractor::Result.new(ok: true, event: event, error: nil)
  end

  test "returns prefill JSON on success and never persists an event" do
    extracted = { "title" => "Sunset Yoga", "date" => "2026-07-01", "time" => "18:00", "description" => "Flow" }
    assert_no_difference "Event.count" do
      Ai::EventImageExtractor.stub(:call, ->(**) { ok_result(extracted) }) do
        post totem_event_from_photo_path(@totem.slug), params: { image: DATA_URL }, as: :json
      end
    end
    assert_response :success
    assert_equal extracted, JSON.parse(response.body)["event"]
  end

  test "rejects a missing or non-image payload" do
    post totem_event_from_photo_path(@totem.slug), params: { image: "" }, as: :json
    assert_response :unprocessable_entity
    post totem_event_from_photo_path(@totem.slug), params: { image: "not-a-data-url" }, as: :json
    assert_response :unprocessable_entity
  end

  test "surfaces an extractor failure as 422" do
    Ai::EventImageExtractor.stub(:call, ->(**) { Ai::EventImageExtractor::Result.new(ok: false, event: nil, error: "x") }) do
      post totem_event_from_photo_path(@totem.slug), params: { image: DATA_URL }, as: :json
    end
    assert_response :unprocessable_entity
  end

  # Same fail-open guarantee as the text submission path: a cache-backend outage
  # must not 500 the photo extraction.
  test "succeeds when the cache backend raises (fail-open throttle)" do
    failing_cache = Class.new do
      def read(*)  = raise(ActiveRecord::StatementInvalid, 'relation "solid_cache_entries" does not exist')
      def write(*) = raise(ActiveRecord::StatementInvalid, 'relation "solid_cache_entries" does not exist')
    end.new

    Rails.stub(:cache, failing_cache) do
      Ai::EventImageExtractor.stub(:call, ->(**) { ok_result({ "title" => "Y" }) }) do
        post totem_event_from_photo_path(@totem.slug), params: { image: DATA_URL }, as: :json
      end
    end
    assert_response :success
  end

  # The image is forwarded to a paid vision model — oversized payloads are
  # rejected before the AI call.
  test "rejects an oversized image without calling the extractor" do
    called = false
    huge = "data:image/jpeg;base64," +
      ("a" * (Totems::EventPhotoExtractionsController::MAX_IMAGE_BYTES + 1))
    Ai::EventImageExtractor.stub(:call, ->(**) { called = true; ok_result({ "title" => "Y" }) }) do
      post totem_event_from_photo_path(@totem.slug), params: { image: huge }, as: :json
    end
    assert_response 413
    assert_not called
  end

  test "unknown totem returns 404" do
    post totem_event_from_photo_path("no-such-totem"), params: { image: DATA_URL }, as: :json
    assert_response :not_found
  end

  test "throttles after the per-IP limit" do
    store = ActiveSupport::Cache::MemoryStore.new
    Rails.stub(:cache, store) do
      Ai::EventImageExtractor.stub(:call, ->(**) { ok_result({ "title" => "Y" }) }) do
        Totems::EventPhotoExtractionsController::THROTTLE_LIMIT.times do
          post totem_event_from_photo_path(@totem.slug), params: { image: DATA_URL }, as: :json
        end
        post totem_event_from_photo_path(@totem.slug), params: { image: DATA_URL }, as: :json
      end
    end
    assert_response :too_many_requests
  end
end
