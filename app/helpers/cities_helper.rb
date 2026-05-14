module CitiesHelper
  def city_board_active_event(totem)
    now = Time.current
    window_start = now - Event::CHECKIN_WINDOW_AFTER_MINUTES.minutes
    window_end   = now + Event::CHECKIN_WINDOW_BEFORE_MINUTES.minutes

    totem.events
      .select { |e| e.active? && e.start_time <= window_end && e.end_time >= window_start }
      .min_by { |e| e.start_time <= now && e.end_time >= now ? 0 : 1 }
  end

  def city_board_week_events(totem)
    now       = Time.current
    week_end  = now + 7.days
    threshold = now + Event::CHECKIN_WINDOW_BEFORE_MINUTES.minutes

    totem.events
      .select { |e| e.active? && !city_board_active?(e, now) }
      .select { |e| e.next_occurrence > threshold && e.next_occurrence <= week_end }
      .sort_by(&:next_occurrence)
  end

  def city_board_event_day_label(event)
    occurrence = event.next_occurrence
    today      = Time.current.to_date

    case occurrence.to_date
    when today     then "Tonight"
    when today + 1 then "Tomorrow"
    else occurrence.strftime("%a, %b %-d")
    end
  end

  private

  def city_board_active?(event, now = Time.current)
    window_start = now - Event::CHECKIN_WINDOW_AFTER_MINUTES.minutes
    window_end   = now + Event::CHECKIN_WINDOW_BEFORE_MINUTES.minutes
    event.start_time <= window_end && event.end_time >= window_start
  end
end
