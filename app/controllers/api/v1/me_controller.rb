class Api::V1::MeController < Api::V1::ApplicationController
  def show
    render json: user_json(current_user)
  end

  def update
    permitted = params.permit(:name, notification_prefs: [:new_event, :reminder, :all])
    if current_user.update(permitted)
      render json: user_json(current_user)
    else
      render json: { error: current_user.errors.full_messages.first }, status: :unprocessable_entity
    end
  end

  def destroy
    current_user.destroy
    head :no_content
  end

  def check_ins
    check_ins = current_user.check_ins
      .includes(event: { totem: {}, host_user: :host_profile })
      .order(checked_in_at: :desc)

    render json: {
      check_ins: check_ins.map { |ci|
        {
          id: ci.id,
          checked_in_at: ci.checked_in_at.iso8601,
          event: {
            id: ci.event_id,
            title: ci.event.title,
            slug: ci.event.slug,
            start_time: ci.event.start_time.iso8601,
            totem_name: ci.event.totem.name,
            totem_slug: ci.event.totem.slug
          }
        }
      }
    }
  end

  def subscriptions
    favorites = current_user.totem_favorites.includes(:totem)
    follows   = current_user.host_follows.includes(:host_user)

    render json: {
      totem_favorites: favorites.map { |f|
        {
          id: f.id,
          totem_id: f.totem_id,
          totem_name: f.totem.name,
          totem_slug: f.totem.slug,
          notify_new_event: f.notify_new_event,
          notify_reminder: f.notify_reminder
        }
      },
      host_follows: follows.map { |f|
        {
          id: f.id,
          host_user_id: f.host_user_id,
          host_name: f.host_user.name,
          notify_new_event: f.notify_new_event,
          notify_reminder: f.notify_reminder
        }
      }
    }
  end

  def push_token
    token = params[:push_token]
    return render json: { error: "push_token is required" }, status: :unprocessable_entity if token.blank?

    if current_user.update(push_token: token)
      head :no_content
    else
      render json: { error: current_user.errors.full_messages.first }, status: :unprocessable_entity
    end
  end

  private

  def user_json(user)
    json = {
      id: user.id,
      name: user.name,
      email: user.email,
      auth_method: user.auth_method,
      is_host: user.is_host,
      is_admin: user.is_admin,
      push_token: user.push_token,
      notification_prefs: user.notification_prefs
    }
    if user.is_host?
      token = JwtService.encode(user_id: user.id, exp: 5.minutes.from_now.to_i)
      base  = ENV.fetch("HOST_DASHBOARD_URL", "https://host.signalfire.live")
      json[:host_sso_url] = "#{base}/host/dashboard?sso_token=#{token}"
    end
    json
  end
end
