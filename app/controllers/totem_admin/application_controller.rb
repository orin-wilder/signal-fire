class TotemAdmin::ApplicationController < ApplicationController
  layout "host"
  before_action :require_totem_admin!

  private

  # Gate: signed-in user with at least one role: totem_admin assignment (super admins too).
  def require_totem_admin!
    return if current_user&.is_admin?

    unless current_user && current_user.host_totem_assignments.any?(&:role_totem_admin?)
      redirect_to sign_in_path, alert: "You don't have totem admin access."
    end
  end

  # Totems this user moderates — the scope for every action in this namespace.
  def moderated_totems
    @moderated_totems ||= Totem.where(id: current_user.moderated_totem_ids).order(:name)
  end
  helper_method :moderated_totems
end
