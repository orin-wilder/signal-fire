class Totems::EventsController < ApplicationController
  before_action :set_totem_and_event

  def show
    @window_state = @event.window_state
    @host_profile = @event.host_user&.host_profile
    @host_follow  = current_user &&
      HostFollow.find_by(user: current_user, host_user_id: @event.host_user_id)

    AnalyticsService.track(
      "event_detail_viewed",
      event_id: @event.id,
      totem_id: @totem.id,
      auth_state: current_user ? :authenticated : :anonymous,
      source: params[:source] || :direct
    )
    record_analytics_event("event_view", totem: @totem, event: @event, source: params[:source] || "direct")
  end

  def calendar
    ics = IcsService.generate(@event)
    AnalyticsService.track("event_calendar_saved",
      event_id: @event.id, user_id: current_user&.id)
    record_analytics_event("calendar_add", totem: @totem, event: @event)
    send_data ics,
      type:        "text/calendar; charset=utf-8",
      disposition: "attachment",
      filename:    "#{@event.slug}.ics"
  end

  private

  def set_totem_and_event
    @totem = Totem.find_by!(slug: params[:slug])
    @event = @totem.events.find_by!(slug: params[:event_slug])
  end
end
