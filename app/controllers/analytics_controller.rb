class AnalyticsController < ApplicationController
  def track
    AnalyticsService.track(
      params[:event].to_s,
      user_id: current_user&.id,
      **params.permit(:event_id).to_h.symbolize_keys
    )
    head :no_content
  end
end
