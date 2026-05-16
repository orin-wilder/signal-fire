class Host::ApplicationController < ApplicationController
  layout "host"
  before_action :require_host!

  private

  def require_host!
    if params[:sso_token].present?
      payload = JwtService.decode(params[:sso_token])
      user    = User.find_by(id: payload&.dig("user_id"))
      if user&.is_host? && user.host_profile&.active?
        session[:user_id] = user.id
        return redirect_to host_dashboard_path
      end
    end
    super
  end
end
