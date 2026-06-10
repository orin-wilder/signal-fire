class Api::V1::TotemsController < Api::V1::ApplicationController
  include Api::V1::Concerns::EventSerializer

  skip_before_action :authenticate_api_user!
  before_action :optionally_authenticate_api_user!

  def show
    totem = Totem.find_by(slug: params[:slug])
    return render json: { error: "Not found" }, status: :not_found unless totem

    active_events = totem.events
      .includes(host_user: :host_profile)
      .select { |e| e.active? && e.publicly_visible? }

    preload_user_event_data(active_events)

    active_now, upcoming = partition_events(active_events)
    following = current_user ? current_user.totem_favorites.exists?(totem: totem) : nil

    render json: {
      totem: {
        id: totem.id,
        name: totem.name,
        slug: totem.slug,
        location: totem.location,
        sublocation: totem.sublocation,
        active: totem.active,
        empty: board_empty?(totem, active_events),
        following: following,
        active_now: active_now.map { |e| build_event_json(e) },
        upcoming: upcoming.map { |e| build_event_json(e) }
      }
    }
  end

  private

  def board_empty?(totem, active_events)
    return true unless totem.active

    now = Time.current
    has_upcoming = active_events.any? { |e| e.weekly? || (e.one_time? && e.start_time > now) }
    has_recent   = active_events.any? { |e| e.end_time > 30.days.ago && e.end_time < now }
    !has_upcoming && !has_recent
  end
end
