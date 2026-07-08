class HostsController < ApplicationController
  def show
    @host_profile = HostProfile.active.find_by!(slug: params[:host_slug])
    @host_user    = @host_profile.user
    @upcoming_events = Event
      .publicly_visible
      .where(host_user: @host_user, status: :active)
      .where("start_time > ?", Time.current)
      .includes(:totem)
      .order(:start_time)
    @totems = Totem
      .joins(:host_totem_assignments)
      .where(host_totem_assignments: { host_user_id: @host_user.id })
      .distinct

    AnalyticsService.track("host_page_viewed", host_slug: params[:host_slug])
  end
end
