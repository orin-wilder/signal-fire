module ApplicationHelper
  def app_nudges_enabled?
    ENV["APP_NUDGES_ENABLED"] == "true"
  end

  def host_sso_url
    return unless current_user&.is_host?
    token = JwtService.encode(user_id: current_user.id, exp: 5.minutes.from_now.to_i)
    base = ENV.fetch("HOST_DASHBOARD_URL", "https://host.signalfire.live")
    "#{base}/host/dashboard?sso_token=#{token}"
  end
end
