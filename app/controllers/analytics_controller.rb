class AnalyticsController < ApplicationController
  def track
    AnalyticsService.track(
      params[:event].to_s,
      user_id: current_user&.id,
      **params.permit(:event_id).to_h.symbolize_keys
    )

    if params[:event].to_s == "event_shared"
      event = Event.find_by(id: params[:event_id])
      record_analytics_event("event_share", totem: event&.totem, event: event)
    end

    head :no_content
  end
end
