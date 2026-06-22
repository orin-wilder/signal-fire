class Totems::BoardsController < ApplicationController
  def show
    @totem = Totem.find_by!(slug: params[:slug])

    if params[:dismiss_footer]
      cookies[:footer_dismissed] = { value: "1", path: "/" }
      return redirect_to totem_board_path(@totem.slug)
    end

    session[:return_to] = request.path unless signed_in?

    AnalyticsService.track(
      "totem_board_viewed",
      totem_id: @totem.id,
      auth_state: current_user ? :authenticated : :anonymous,
      source: params[:source] || :qr_scan
    )
    record_analytics_event("board_view", totem: @totem, source: params[:source] || "qr_scan")

    # One template (Phase 4): board_empty? only decides whether to also show the
    # "notify me" email capture — it no longer forks to a separate page.
    @board_empty      = @totem.board_empty?
    @active_now       = @totem.active_now_events
    @upcoming         = @totem.upcoming_events
    @past             = @totem.past_events
    @host             = @totem.primary_host
    @favorite         = current_user && TotemFavorite.find_by(user: current_user, totem: @totem)
    @footer_dismissed = cookies[:footer_dismissed]
    @nearby           = Event.nearby_upcoming(city_slug: @totem.city_slug, excluding_totem_id: @totem.id)
    @event            = Event.new
  end
end
