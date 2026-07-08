class Api::V1::HomeController < Api::V1::ApplicationController
  include Api::V1::Concerns::EventSerializer

  def index
    render json: {
      sections: {
        yours: build_yours_section,
        st_pete: build_st_pete_section,
        nearby: { visible: false, reason: "no_adjacent_cities" }
      }
    }
  end

  private

  def build_yours_section
    favorite_totem_ids = current_user.totem_favorites.pluck(:totem_id)
    followed_host_ids  = current_user.host_follows.pluck(:host_user_id)

    if favorite_totem_ids.empty? && followed_host_ids.empty?
      return { visible: false }
    end

    items = []

    # Totem favorites
    totem_favorites = current_user.totem_favorites
      .includes(totem: { events: :host_user })
      .where(totem_id: favorite_totem_ids)

    totem_favorites.each do |fav|
      next_event = yours_next_event_for_totem(fav.totem)
      items << {
        type: "totem_favorite",
        sort_key: next_event&.next_occurrence&.to_i || Float::INFINITY,
        totem: {
          id: fav.totem.id,
          name: fav.totem.name,
          slug: fav.totem.slug,
          neighborhood: fav.totem.neighborhood,
          character_description: fav.totem.character_description,
          favorited: true,
          totem_favorite_id: fav.id
        },
        next_event: next_event ? build_next_event_json(next_event) : nil
      }
    end

    # Host follows
    host_follows = current_user.host_follows
      .includes(host_user: [ :host_profile, { events: :totem } ])

    host_follows.each do |follow|
      next_event = yours_next_event_for_host(follow.host_user)
      items << {
        type: "host_follow",
        sort_key: next_event&.next_occurrence&.to_i || Float::INFINITY,
        host: {
          display_name: follow.host_user.host_profile&.display_name || follow.host_user.name,
          slug: follow.host_user.host_profile&.slug,
          following: true,
          host_follow_id: follow.id
        },
        next_event: next_event ? build_next_event_json(next_event) : nil
      }
    end

    sorted = items.sort_by { |item| item.delete(:sort_key) }
    { visible: true, items: sorted }
  end

  def build_st_pete_section
    now = Time.current
    window_end = now + Event::CHECKIN_WINDOW_BEFORE_MINUTES.minutes

    totems = Totem
      .city_board_visible
      .for_city("stpete")
      .includes(events: :host_user, totem_favorites: nil)
      .order(:name)

    favorite_totem_ids = current_user.totem_favorites.pluck(:totem_id).to_set
    favorite_by_totem  = current_user.totem_favorites.index_by(&:totem_id)

    totem_list = totems.map do |totem|
      active_events = totem.events.select { |e|
        e.active? && e.publicly_visible? &&
          e.start_time <= window_end + Event::CHECKIN_WINDOW_AFTER_MINUTES.minutes &&
          e.end_time >= window_end - (Event::CHECKIN_WINDOW_AFTER_MINUTES * 2).minutes
      }
      active_now = active_events.min_by { |e| e.start_time <= now && e.end_time >= now ? 0 : 1 }

      upcoming = totem.events
        .select { |e| e.active? && e.publicly_visible? && !active_events.include?(e) }
        .select { |e| e.next_occurrence > window_end }
        .min_by(&:next_occurrence)

      fav = favorite_by_totem[totem.id]

      {
        id: totem.id,
        name: totem.name,
        slug: totem.slug,
        neighborhood: totem.neighborhood,
        character_description: totem.character_description,
        active_now: active_now.present?,
        favorited: favorite_totem_ids.include?(totem.id),
        totem_favorite_id: fav&.id,
        next_event: upcoming ? build_next_event_json(upcoming) : nil
      }
    end

    { visible: true, totems: totem_list }
  end

  def yours_next_event_for_totem(totem)
    threshold = Time.current + Event::CHECKIN_WINDOW_BEFORE_MINUTES.minutes
    totem.events
      .select { |e| e.active? && e.publicly_visible? && e.next_occurrence > threshold }
      .min_by(&:next_occurrence)
  end

  def yours_next_event_for_host(host_user)
    threshold = Time.current + Event::CHECKIN_WINDOW_BEFORE_MINUTES.minutes
    host_user.events
      .select { |e| e.active? && e.publicly_visible? && e.next_occurrence > threshold }
      .min_by(&:next_occurrence)
  end

  def build_next_event_json(event)
    {
      id: event.id,
      title: event.title,
      start_time: event.next_occurrence.iso8601,
      recurrence_label: event.recurrence_label
    }
  end
end
