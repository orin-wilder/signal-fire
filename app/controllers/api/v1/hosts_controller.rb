class Api::V1::HostsController < Api::V1::ApplicationController
  include Api::V1::Concerns::EventSerializer

  skip_before_action :authenticate_api_user!
  before_action :optionally_authenticate_api_user!

  def show
    host_profile = HostProfile.active.find_by!(slug: params[:host_slug])
    host_user = host_profile.user

    upcoming_events = Event
      .publicly_visible
      .where(host_user: host_user, status: :active)
      .where("start_time > ?", Time.current)
      .includes(:totem)
      .order(:start_time)

    host_follow = current_user &&
      HostFollow.find_by(user: current_user, host_user: host_user)

    preload_user_event_data(upcoming_events) if current_user

    render json: {
      host: {
        slug: host_profile.slug,
        host_user_id: host_user.id,
        display_name: host_profile.display_name,
        host_story: host_profile.host_story,
        following: host_follow.present?,
        host_follow_id: host_follow&.id,
        upcoming_events: upcoming_events.map { |e| build_event_json(e) },
        totems: host_user.assigned_totems.map { |t|
          { name: t.name, slug: t.slug, neighborhood: t.neighborhood }
        }
      }
    }
  end
end
