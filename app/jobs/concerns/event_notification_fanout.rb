module EventNotificationFanout
  # Returns an array of { user:, source_type: } hashes, deduplicated.
  # Users qualifying via both host_follow and totem_favorite get one entry
  # attributed to host_follow (more specific).
  def recipients_for(event)
    by_host_follow = User
      .joins(:host_follows)
      .where(host_follows: { host_user_id: event.host_user_id, notify_new_event: true })
      .distinct
      .index_by(&:id)

    by_totem_favorite = User
      .joins(:totem_favorites)
      .where(totem_favorites: { totem_id: event.totem_id, notify_new_event: true })
      .distinct
      .index_by(&:id)

    all_ids = (by_host_follow.keys + by_totem_favorite.keys).uniq
    all_ids.map do |user_id|
      source = by_host_follow.key?(user_id) ? :host_follow : :totem_favorite
      { user: by_host_follow[user_id] || by_totem_favorite[user_id], source_type: source }
    end
  end

  def reminder_recipients_for(event)
    by_host_follow = User
      .joins(:host_follows)
      .where(host_follows: { host_user_id: event.host_user_id, notify_reminder: true })
      .distinct
      .index_by(&:id)

    by_totem_favorite = User
      .joins(:totem_favorites)
      .where(totem_favorites: { totem_id: event.totem_id, notify_reminder: true })
      .distinct
      .index_by(&:id)

    all_ids = (by_host_follow.keys + by_totem_favorite.keys).uniq
    recipients = all_ids.map do |user_id|
      source = by_host_follow.key?(user_id) ? :host_follow : :totem_favorite
      { user: by_host_follow[user_id] || by_totem_favorite[user_id], source_type: source }
    end

    if event.recurring?
      prior_attendee_ids = CheckIn
        .joins(:event)
        .where(events: { totem_id: event.totem_id, host_user_id: event.host_user_id })
        .where.not(event_id: event.id)
        .distinct
        .pluck(:user_id)
      recipients = recipients.select { |r| prior_attendee_ids.include?(r[:user].id) }
    end

    recipients
  end

  def cancellation_recipients_for(event)
    by_host_follow = User
      .joins(:host_follows)
      .where(host_follows: { host_user_id: event.host_user_id })
      .distinct
      .index_by(&:id)

    by_totem_favorite = User
      .joins(:totem_favorites)
      .where(totem_favorites: { totem_id: event.totem_id })
      .distinct
      .index_by(&:id)

    all_ids = (by_host_follow.keys + by_totem_favorite.keys).uniq
    all_ids.map do |user_id|
      source = by_host_follow.key?(user_id) ? :host_follow : :totem_favorite
      { user: by_host_follow[user_id] || by_totem_favorite[user_id], source_type: source }
    end
  end

  # Creates the delivery record BEFORE pushing, so the unique index — not a
  # check-then-create race — decides whether this notification was already
  # sent. occurrence_date scopes dedup to one occurrence of a recurring event;
  # leave it nil for once-ever types.
  def deliver_to(user:, event:, notification_type:, source_type:, title:, body:, occurrence_date: nil)
    begin
      delivery = NotificationDelivery.create!(
        user: user,
        event: event,
        notification_type: notification_type,
        source_type: source_type,
        occurrence_date: occurrence_date,
        sent_at: Time.current
      )
    rescue ActiveRecord::RecordNotUnique
      return nil # a concurrent worker won the race — already sent
    rescue ActiveRecord::RecordInvalid => e
      raise unless e.record.errors.of_kind?(:user_id, :taken)
      return nil # already sent
    end

    return unless user.push_token.present?

    result = PushNotificationService.deliver(
      push_token: user.push_token,
      title: title,
      body: body,
      data: {
        event_id: event.id,
        event_slug: event.slug,
        totem_slug: event.totem.slug,
        notification_type: notification_type
      }
    )

    user.update_column(:push_token, nil) if result.error == "DeviceNotRegistered"

    AnalyticsService.track(
      "notification_sent",
      user_id: user.id,
      event_id: event.id,
      type: notification_type,
      source_type: source_type
    )

    delivery
  end
end
