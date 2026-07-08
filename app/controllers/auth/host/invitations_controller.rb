class Auth::Host::InvitationsController < ApplicationController
  # Invitation-token brute-force guard (both actions look tokens up).
  rate_limit to: 30, within: 15.minutes, store: RateLimitStore,
    with: -> { redirect_to host_login_path, alert: "Too many attempts. Please wait a few minutes and try again." }

  def edit
    @host_profile = find_valid_profile
    render :invalid_token unless @host_profile
  end

  def update
    @host_profile = find_valid_profile

    unless @host_profile
      render :invalid_token and return
    end

    if params[:password].blank?
      flash.now[:alert] = "Password cannot be blank."
      render :edit, status: :unprocessable_entity and return
    end

    if params[:password] != params[:password_confirmation]
      flash.now[:alert] = "Passwords do not match."
      render :edit, status: :unprocessable_entity and return
    end

    user = @host_profile.user
    user.password = params[:password]

    if user.save
      @host_profile.update!(
        invite_status: :active,
        invite_accepted_at: Time.current,
        invitation_token: nil,
        invitation_token_expires_at: nil
      )
      session[:user_id] = user.id
      redirect_to host_dashboard_path
    else
      flash.now[:alert] = user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def find_valid_profile
    return nil if params[:token].blank?

    profile = HostProfile.find_by(invitation_token: params[:token])
    return nil unless profile
    return nil if profile.invitation_token_expires_at&.past?

    profile
  end
end
