class WeeklyDigestDeliveryJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)

    favorite_totem_ids = TotemFavorite.where(user: user).pluck(:totem_id)
    followed_host_ids  = HostFollow.where(user: user).pluck(:host_user_id)

    if favorite_totem_ids.empty? && followed_host_ids.empty?
      return log_skip(user.id, "no_favorites_or_follows")
    end

    week_ahead = Time.current..(Time.current + 7.days)

    personal_events = Event.active.publicly_visible
      .where(start_time: week_ahead)
      .where(
        "totem_id IN (?) OR host_user_id IN (?)",
        favorite_totem_ids, followed_host_ids
      )
      .includes(:totem, :host_user)
      .order(:start_time)

    city_events = Event.active.publicly_visible
      .where(start_time: week_ahead)
      .where(totem: Totem.city_board_visible.for_city("stpete"))
      .where.not(id: personal_events.pluck(:id))
      .order(:start_time)
      .limit(5)

    if personal_events.empty? && city_events.count < 2
      return log_skip(user.id, "insufficient_content")
    end

    all_events = (personal_events.to_a + city_events.to_a).uniq(&:id)
    first      = all_events.first

    body = if personal_events.any?
      "#{first.title} and more this week at your favorite spots."
    else
      "#{first.title} and #{all_events.size - 1} more happening in St. Pete this week."
    end

    PushNotificationService.deliver(
      push_token: user.push_token,
      title: "What's happening this week",
      body:  body,
      data:  { type: "weekly_digest" }
    )

    source = personal_events.any? ? :host_follow : :totem_favorite
    NotificationDelivery.create(
      user:              user,
      event:             first,
      notification_type: :weekly_digest,
      source_type:       source,
      sent_at:           Time.current
    )

    AnalyticsService.track("weekly_digest_sent",
      user_id: user.id, event_count: all_events.size)
  end

  private

  def log_skip(user_id, reason)
    AnalyticsService.track("weekly_digest_skipped", user_id: user_id, reason: reason)
  end
end
