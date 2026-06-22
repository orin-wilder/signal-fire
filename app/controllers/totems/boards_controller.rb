class Totems::BoardsController < ApplicationController
  def show
    @totem = Totem.find_by!(slug: params[:slug])

    if params[:dismiss_footer]
      cookies[:footer_dismissed] = { value: "1", path: "/" }
      return redirect_to totem_board_path(@totem.slug)
    end

    session[:return_to] = request.path unless signed_in?

    # Compute social proof from prior traffic, before recording this visit, so a
    # brand-new totem's first scanner isn't counted as "1 person stopped by".
    @board_activity = board_activity(@totem)

    AnalyticsService.track(
      "totem_board_viewed",
      totem_id: @totem.id,
      auth_state: current_user ? :authenticated : :anonymous,
      source: params[:source] || :qr_scan
    )
    board_source = params[:source] || "qr_scan"
    record_analytics_event("board_view", totem: @totem, source: board_source)
    # Count the physical scan here for QR/direct entry. Typed short-codes are
    # already counted in Totems::ShortCodesController before the redirect, so skip
    # them to avoid double-counting.
    record_analytics_event("totem_scan", totem: @totem, source: board_source) unless board_source == "short_code"

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

  private

  # Lightweight social-proof signals for the masthead so even an empty board
  # reads as a place people actually use. Only non-zero values are rendered.
  def board_activity(totem)
    visitors_this_week = AnalyticsEvent
      .where(totem_id: totem.id, name: %w[totem_scan board_view])
      .where("occurred_at > ?", 7.days.ago)
      .where.not(visitor_hash: nil)
      .distinct.count(:visitor_hash)

    # Lifetime attendance: authenticated check-ins + the aggregate anonymous
    # counter (which has no per-row timestamp, so it can't be windowed).
    authed_checkins    = CheckIn.joins(:event).where(events: { totem_id: totem.id }).count
    anonymous_checkins = AnonymousCheckInCount.joins(:event).where(events: { totem_id: totem.id }).sum(:count)

    { visitors_this_week: visitors_this_week, total_checkins: authed_checkins + anonymous_checkins }
  end
end
