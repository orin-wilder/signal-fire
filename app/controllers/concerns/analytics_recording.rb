# Records lightweight, cookieless traffic signals into the analytics_events
# table alongside the existing PostHog tracking. Included into every controller
# via ApplicationController.
#
# Privacy: the visitor identifier is a one-way SHA256 digest of IP + user-agent +
# the current date + the app secret. It rotates daily, sets no cookie, and never
# stores a raw IP — so "unique visitors" is a rough, privacy-clean count
# (effectively visitor-days), not a persistent identity.
module AnalyticsRecording
  extend ActiveSupport::Concern

  private

  def record_analytics_event(name, totem: nil, event: nil, source: nil)
    AnalyticsEvent.create!(
      name: name,
      totem_id: totem&.id,
      event_id: event&.id,
      user_id: current_user&.id,
      source: source&.to_s,
      visitor_hash: current_visitor_hash,
      occurred_at: Time.current
    )
  rescue => e
    # Analytics must never break a request.
    Rails.logger.error("[AnalyticsRecording] Failed to record #{name}: #{e.message}")
  end

  def current_visitor_hash
    @current_visitor_hash ||= Digest::SHA256.hexdigest(
      [ request.remote_ip, request.user_agent, Date.current.to_s, Rails.application.secret_key_base ].join("|")
    )
  end
end
