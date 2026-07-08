require "net/http"
require "cgi"

class Api::V1::Auth::GoogleController < ActionController::API
  # Each call proxies to Google's tokeninfo endpoint; default with: raises → 429.
  rate_limit to: 15, within: 3.minutes, only: :create, store: RateLimitStore

  GOOGLE_TOKENINFO_URL = "https://oauth2.googleapis.com/tokeninfo"

  def create
    id_token = params[:id_token]
    return render json: { error: "id_token is required" }, status: :bad_request if id_token.blank?

    google_payload = verify_google_token(id_token)
    return render json: { error: "Invalid Google token" }, status: :unauthorized unless google_payload

    google_uid = google_payload["sub"]
    email = google_payload["email"]
    name = google_payload["name"]

    user = User.find_by(google_uid: google_uid) ||
           User.find_by(email: email)

    if user
      user.update!(google_uid: google_uid, auth_method: :google)
    else
      user = User.create!(
        google_uid: google_uid,
        email: email,
        name: name,
        auth_method: :google
      )
    end

    token = JwtService.encode(user_id: user.id)
    AnalyticsService.identify(user.id, email: user.email, auth_method: user.auth_method, is_host: user.is_host)
    render json: { token: token, user: user.slice(:id, :name, :email, :is_host, :is_admin) }
  end

  private

  def verify_google_token(id_token)
    response = Net::HTTP.get_response(URI("#{GOOGLE_TOKENINFO_URL}?id_token=#{CGI.escape(id_token)}"))
    return nil unless response.is_a?(Net::HTTPSuccess)

    payload = JSON.parse(response.body)
    return nil unless payload["aud"] == ENV["GOOGLE_CLIENT_ID_MOBILE"]

    payload
  rescue StandardError
    nil
  end
end
