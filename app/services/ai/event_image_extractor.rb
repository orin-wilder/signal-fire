module Ai
  # Extracts a single event from a photo (a flyer, poster, chalkboard, etc.).
  # Sends a base64 data-URL image to a vision model via OpenRouterClient and
  # returns structured fields to PRE-FILL the submission form — nothing is
  # persisted and the image never touches storage (base64 in-request only).
  # Owns the prompt + schema; OpenRouterClient owns transport (multimodal
  # `messages` pass through unchanged). Mirrors Ai::EventScout's single-event shape.
  class EventImageExtractor
    VISION_MODEL = "google/gemini-2.5-flash" # vision-capable, non-:online (no web search)

    Result = Data.define(:ok, :event, :error)

    # Single-event shape (subset of EventScout::SCHEMA). All fields nullable — the
    # model returns null for anything the photo doesn't show, and the user edits
    # the prefilled form before submitting.
    SCHEMA = {
      type: "object",
      additionalProperties: false,
      properties: {
        title:       { type: %w[string null] },
        description: { type: %w[string null] },
        date:        { type: %w[string null] },
        time:        { type: %w[string null] },
        location:    { type: %w[string null] }
      },
      required: %w[title description date time location]
    }.freeze

    FIELDS = %w[title description date time location].freeze

    def self.call(image_data_url:, http_client: nil)
      return Result.new(ok: false, event: nil, error: "no image") if image_data_url.blank?

      args = {
        model: VISION_MODEL,
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: [
            { type: "text", text: USER_PROMPT },
            { type: "image_url", image_url: { url: image_data_url } }
          ] }
        ],
        response_format: { type: "json_schema", json_schema: { name: "event", strict: true, schema: SCHEMA } }
      }
      args[:http_client] = http_client if http_client

      res = OpenRouterClient.chat(**args)
      return Result.new(ok: false, event: nil, error: res.error) unless res.ok

      content = res.data.dig("choices", 0, "message", "content").to_s
      parsed = begin
        JSON.parse(content)
      rescue JSON::ParserError
        nil
      end
      return Result.new(ok: false, event: nil, error: "unparseable AI response") if parsed.nil?

      Result.new(ok: true, event: parsed.slice(*FIELDS), error: nil)
    end

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You read photos of event flyers, posters, signs, and chalkboards for Signal
      Fire, a hyperlocal community board. Extract the single event the image is
      advertising. Only report what the image actually shows — never invent a
      title, date, time, or location. Return null for anything not clearly shown.
    PROMPT

    USER_PROMPT = <<~PROMPT.freeze
      Extract the event from this photo. Use date format YYYY-MM-DD and 24-hour
      time HH:MM. If the photo shows a day/time but no explicit calendar date,
      infer the nearest upcoming date. Use null for any field the photo doesn't
      clearly show. Keep description to one short line.
    PROMPT
  end
end
