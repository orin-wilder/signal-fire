class ApplicationController < ActionController::Base
  allow_browser versions: :modern if Rails.env.production?
  stale_when_importmap_changes

  helper_method :current_user, :signed_in?, :can_moderate_totem?

  private

  # True when the current user can moderate (approve/edit/delete) events on the totem.
  def can_moderate_totem?(totem)
    current_user&.can_moderate_totem?(totem) || false
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def signed_in?
    current_user.present?
  end

  def after_auth_path
    session.delete(:return_to) || about_path
  end

  def require_user!
    redirect_to sign_in_path, alert: "Please sign in." unless current_user
  end

  def require_host!
    unless current_user&.is_host? && current_user&.host_profile&.active?
      redirect_to host_login_path, alert: "Please sign in to access the host dashboard."
    end
  end

  def require_admin!
    unless current_user&.is_admin?
      redirect_to admin_login_path, alert: "Please sign in as an admin."
    end
  end

  def require_totem_moderator!(totem)
    unless can_moderate_totem?(totem)
      redirect_to sign_in_path, alert: "You don't have permission to moderate this totem."
    end
  end
end
