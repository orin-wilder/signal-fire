class Host::InsightsController < Host::ApplicationController
  def show
    @event = Event
      .joins(totem: :host_totem_assignments)
      .where(host_totem_assignments: { host_user_id: current_user.id })
      .find_by!(slug: params[:event_slug])

    raise ActiveRecord::RecordNotFound if @event.end_time >= Time.current

    @authenticated_checkins = @event.check_ins.count
    @anonymous_checkins     = @event.anonymous_check_in_count&.count || 0
    @total_checkins         = @authenticated_checkins + @anonymous_checkins
    @follower_count         = HostFollow.where(host_user: @event.host_user).count
    @first_timer_count      = first_timer_count
    @checkins_by_window     = checkins_by_15min_window
    @attendee_names         = first_names_with_counts

    AnalyticsService.track("event_insights_viewed",
      user_id: current_user.id,
      event_id: @event.id)
  end

  private

  def checkins_by_15min_window
    window_start = @event.start_time - 30.minutes
    window_end   = @event.end_time   + 30.minutes

    @event.check_ins
      .where(checked_in_at: window_start..window_end)
      .to_a
      .group_by { |ci|
        offset_minutes = ((ci.checked_in_at - @event.start_time) / 60).to_i
        (offset_minutes / 15) * 15
      }
      .transform_values(&:count)
      .sort_by { |window, _| window }
      .to_h
  end

  def first_names_with_counts
    @event.check_ins
      .joins(:user)
      .pluck("users.name")
      .map    { |n| n.to_s.split.first.presence || "—" }
      .tally
      .sort_by { |_, count| -count }
  end

  def first_timer_count
    window = (@event.start_time - 1.hour)..(@event.end_time + 1.hour)
    first_timer_user_ids = UserHostFirstSeen
      .where(host_user: @event.host_user)
      .where(first_seen_at: window)
      .pluck(:user_id)
    @event.check_ins.where(user_id: first_timer_user_ids).count
  end
end
