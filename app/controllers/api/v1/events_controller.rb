class Api::V1::EventsController < Api::V1::ApplicationController
  include Api::V1::Concerns::EventSerializer

  skip_before_action :authenticate_api_user!
  before_action :optionally_authenticate_api_user!

  def show
    totem = Totem.find_by(slug: params[:totem_slug])
    return render json: { error: "Not found" }, status: :not_found unless totem

    event = totem.events.publicly_visible.includes(host_user: :host_profile).find_by(slug: params[:event_slug])
    return render json: { error: "Not found" }, status: :not_found unless event

    preload_user_event_data([ event ])

    render json: { event: build_event_json(event) }
  end
end
