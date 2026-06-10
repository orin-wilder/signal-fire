# Single transport/auth/error wrapper for all OpenRouter (AI) calls.
# Callers own the model id, prompt construction, and response parsing; this
# class only sends the request and normalizes success/failure. Mirrors
# PushNotificationService: a Data result + an injectable http_client seam so
# tests can stub the network without hitting OpenRouter.
class OpenRouterClient
  CHAT_URL = "https://openrouter.ai/api/v1/chat/completions"
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 30

  # Default model for all AI features — cheap + capable, fits the $20/mo cap.
  # NOTE: OpenRouter retires slugs (e.g. the old gemini-2.0-flash-001 now 404s),
  # so keep this as the single source of truth and verify against
  # https://openrouter.ai/api/v1/models before changing.
  DEFAULT_MODEL = "google/gemini-2.5-flash-lite"

  Result = Data.define(:ok, :data, :error)

  # The real HTTP path. Net::HTTP defaults to infinite timeouts, so set them
  # explicitly here. Tests inject a fake module responding to .post instead.
  module DefaultHTTP
    def self.post(uri, body, headers)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      http.post(uri.path, body, headers)
    end
  end

  def self.chat(model:, messages:, response_format: nil, plugins: nil, http_client: DefaultHTTP)
    key = ENV.fetch("OPENROUTER_API_KEY", nil)
    return Result.new(ok: false, data: nil, error: "missing OPENROUTER_API_KEY") if key.blank?

    payload = { model: model, messages: messages }
    payload[:response_format] = response_format if response_format
    payload[:plugins] = plugins if plugins

    response = http_client.post(
      URI(CHAT_URL),
      payload.to_json,
      "Authorization" => "Bearer #{key}",
      "Content-Type"  => "application/json"
    )

    body = JSON.parse(response.body)

    if (err = body["error"])
      Rails.logger.warn("[OpenRouterClient] API error: #{err}")
      Result.new(ok: false, data: nil, error: err.to_s)
    else
      Result.new(ok: true, data: body, error: nil)
    end
  rescue StandardError => e
    Rails.logger.error("[OpenRouterClient] #{e.class}: #{e.message}")
    Result.new(ok: false, data: nil, error: e.message)
  end
end
