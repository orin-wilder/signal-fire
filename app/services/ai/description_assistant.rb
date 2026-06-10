module Ai
  # Composes OpenRouterClient to rewrite ("enhance") or condense ("summarize")
  # an event description. Owns the prompts + parsing; OpenRouterClient owns
  # transport. Returns a small Data result so callers don't touch raw JSON.
  class DescriptionAssistant
    MODEL = "google/gemini-2.0-flash-001"

    Result = Data.define(:ok, :text, :error)

    ENHANCE_SYSTEM = <<~PROMPT.freeze
      You are an editor for Signal Fire, a hyperlocal community events board.
      Rewrite the event description below to be warmer and more compelling while
      staying truthful, concrete, and roughly the same length. Do not invent
      facts, dates, prices, hosts, or locations. Return only the rewritten
      description with no preamble or quotation marks.
    PROMPT

    def self.enhance(text:, http_client: nil)
      chat(system: ENHANCE_SYSTEM, user: text, http_client: http_client)
    end

    def self.summarize(text:, max: 160, http_client: nil)
      system = <<~PROMPT
        You write ultra-short blurbs for event cards. Summarize the event
        description below in #{max} characters or fewer. Be concrete and plain.
        Return only the summary, no quotation marks or preamble.
      PROMPT

      result = chat(system: system, user: text, http_client: http_client)
      return result unless result.ok

      # Enforce the cap defensively — the model can overshoot.
      Result.new(ok: true, text: result.text.to_s.strip.first(max), error: nil)
    end

    def self.chat(system:, user:, http_client:)
      args = {
        model: MODEL,
        messages: [
          { role: "system", content: system },
          { role: "user", content: user }
        ]
      }
      args[:http_client] = http_client if http_client

      result = OpenRouterClient.chat(**args)
      return Result.new(ok: false, text: nil, error: result.error) unless result.ok

      content = result.data.dig("choices", 0, "message", "content").to_s.strip
      if content.blank?
        Result.new(ok: false, text: nil, error: "empty response")
      else
        Result.new(ok: true, text: content, error: nil)
      end
    end
    private_class_method :chat
  end
end
