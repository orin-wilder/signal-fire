class HostFollowsController < ApplicationController
  before_action :require_user!

  def create
    HostFollow.find_or_create_by!(
      user:        current_user,
      host_user_id: params[:host_user_id]
    )
    redirect_back fallback_location: root_path
  end

  def destroy
    current_user.host_follows.find(params[:id]).destroy
    redirect_back fallback_location: root_path
  end
end
