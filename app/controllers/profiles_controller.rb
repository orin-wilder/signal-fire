class ProfilesController < ApplicationController
  before_action :require_user!

  def show
    @totem_favorites = current_user.totem_favorites.includes(:totem)
    @host_follows    = current_user.host_follows.includes(host_user: :host_profile)
  end
end
