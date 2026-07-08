module Api::V1::Concerns::EventSerializer
  extend ActiveSupport::Concern

  private

  # Builds a hash for a single event. Expects check_ins_by_event and
  # followed_host_ids to be set as instance variables when current_user
  # is present (avoids per-event DB queries).
  def build_event_json(event)
    # host_user is optional (board submissions / scouted events) — the host key
    # stays present with nullable sub-fields, per the frozen API contract.
    host_profile = event.host_user&.host_profile

    check_in    = nil
    following   = nil
    host_follow = nil

    if current_user
      check_in    = @check_ins_by_event&.fetch(event.id, nil)
      following   = @followed_host_ids&.include?(event.host_user_id) || false
      host_follow = @host_follows_by_host_id&.fetch(event.host_user_id, nil)
    end

    {
      id: event.id,
      title: event.title,
      slug: event.slug,
      recurrence_rule: event.recurrence_rule,
      recurrence_label: event.recurrence_label,
      start_time: event.start_time.iso8601,
      end_time: event.end_time.iso8601,
      next_occurrence: event.next_occurrence.iso8601,
      chat_url: event.chat_url,
      chat_platform: event.chat_platform,
      status: event.status,
      description: event.description,
      community_norms: event.community_norms,
      window_state: event.window_state,
      host: {
        id:             event.host_user_id,
        slug:           host_profile&.slug,
        name:           host_profile&.display_name || event.host_user&.name,
        blurb:          host_profile&.blurb,
        following:      following,
        host_follow_id: host_follow&.id
      },
      share_url:        "https://signalfire.live/t/#{event.totem.slug}/e/#{event.slug}",
      calendar_url:     "https://signalfire.live/t/#{event.totem.slug}/e/#{event.slug}/calendar.ics",
      user_checked_in: current_user ? check_in.present? : nil,
      checked_in_at: check_in&.checked_in_at&.iso8601,
      following: following
    }
  end

  # Splits preloaded active events into active_now and upcoming buckets.
  def partition_events(active_events)
    now = Time.current
    window_before = now - Event::CHECKIN_WINDOW_AFTER_MINUTES.minutes
    window_after  = now + Event::CHECKIN_WINDOW_BEFORE_MINUTES.minutes

    active_now = active_events
      .select { |e| e.start_time <= window_after && e.end_time >= window_before }
      .sort_by { |e|
        if e.start_time <= now && e.end_time >= now then [0, e.start_time.to_i]
        elsif e.start_time > now                    then [1, e.start_time.to_i]
        else                                             [2, -e.end_time.to_i]
        end
      }

    upcoming = (active_events - active_now)
      .select { |e| e.next_occurrence > window_after }
      .sort_by(&:next_occurrence)

    [ active_now, upcoming ]
  end

  # Loads auth-scoped look-up tables for a list of events. Call once per
  # request to avoid N+1 when serializing multiple events.
  def preload_user_event_data(events)
    return unless current_user

    event_ids = events.map(&:id)
    @check_ins_by_event = current_user.check_ins
      .where(event_id: event_ids)
      .index_by(&:event_id)
    host_follows = current_user.host_follows.to_a
    @followed_host_ids     = host_follows.map(&:host_user_id).to_set
    @host_follows_by_host_id = host_follows.index_by(&:host_user_id)
  end
end
