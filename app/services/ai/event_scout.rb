module Ai
  # Uses OpenRouter web search + structured output to find real upcoming public
  # events near a totem. Owns the prompt, schema, and parsing; OpenRouterClient
  # owns transport. Returns a Data result with an array of candidate hashes
  # (string keys), each guaranteed to have an http(s) source_url.
  class EventScout
    MODEL = "google/gemini-2.5-flash:online" # :online enables OpenRouter web search
    MAX_RESULTS = 20
    WEB_RESULTS = 5

    Result = Data.define(:ok, :candidates, :error)

    SCHEMA = {
      type: "object",
      additionalProperties: false,
      properties: {
        events: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            properties: {
              title:       { type: "string" },
              description: { type: "string" },
              date:        { type: "string" },
              time:        { type: %w[string null] },
              location:    { type: "string" },
              source_url:  { type: "string" },
              organizer:   { type: %w[string null] }
            },
            required: %w[title description date time location source_url organizer]
          }
        }
      },
      required: %w[events]
    }.freeze

    def self.call(totem:, http_client: nil)
      args = {
        model: MODEL,
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: user_prompt(totem) }
        ],
        response_format: { type: "json_schema", json_schema: { name: "events", strict: true, schema: SCHEMA } },
        plugins: [ { id: "web", max_results: WEB_RESULTS } ]
      }
      args[:http_client] = http_client if http_client

      res = OpenRouterClient.chat(**args)
      return Result.new(ok: false, candidates: [], error: res.error) unless res.ok

      content = res.data.dig("choices", 0, "message", "content").to_s
      parsed = begin
        JSON.parse(content)
      rescue JSON::ParserError
        nil
      end
      return Result.new(ok: false, candidates: [], error: "unparseable AI response") if parsed.nil?

      candidates = Array(parsed["events"]).select do |e|
        e["title"].to_s.present? && e["source_url"].to_s.match?(%r{\Ahttps?://}i)
      end.first(MAX_RESULTS)

      Result.new(ok: true, candidates: candidates, error: nil)
    end

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are an events researcher for Signal Fire, a hyperlocal community board in
      St. Petersburg, Florida. Find REAL, upcoming, public events near the given
      location. Only include events you can attribute to a real source URL. Never
      invent events, dates, times, or URLs. Prefer community-relevant gatherings.
    PROMPT

    def self.user_prompt(totem)
      lines = [ "Location: #{totem.name}" ]
      lines << "Neighborhood: #{totem.neighborhood}" if totem.neighborhood.present?
      lines << "Area/address: #{totem.location}" if totem.location.present?
      lines << "City: St. Petersburg, Florida"
      <<~TXT
        #{lines.join("\n")}

        Find up to #{MAX_RESULTS} real, public events happening within the next 30 days
        from #{Date.current.iso8601} near this location. Each event MUST include a real
        source_url. Use date format YYYY-MM-DD; use null for time if unknown.
      TXT
    end
  end
end
