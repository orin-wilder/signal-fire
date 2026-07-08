class Auth::Host::MagicLinksController < ApplicationController
  # Email-bombing guard (create sends mail) and token brute-force guard (verify).
  rate_limit to: 5, within: 15.minutes, only: :create, store: RateLimitStore, name: "send",
    with: -> { redirect_to host_magic_link_path, alert: "Too many attempts. Please wait a few minutes and try again." }
  rate_limit to: 30, within: 15.minutes, only: :verify, store: RateLimitStore, name: "verify",
    with: -> { redirect_to host_login_path, alert: "Too many attempts. Please wait a few minutes and try again." }

  def new
  end

  def sent
  end

  def create
    user = User.find_by(email: params[:email]&.downcase)

    if user&.is_host? && user.host_profile&.active?
      user.host_profile.update!(
        magic_link_token: SecureRandom.urlsafe_base64(32),
        magic_link_token_expires_at: 30.minutes.from_now
      )
      HostMailer.magic_link_email(user.host_profile).deliver_later
    end

    # Always show success to avoid email enumeration
    redirect_to host_magic_link_sent_path
  end

  def verify
    profile = HostProfile.find_by(magic_link_token: params[:token])

    if profile&.magic_link_token_expires_at&.future? && profile.active?
      profile.update!(magic_link_token: nil, magic_link_token_expires_at: nil)
      session[:user_id] = profile.user_id
      redirect_to host_dashboard_path, notice: "Welcome back!"
    else
      redirect_to host_magic_link_path, alert: "That sign-in link has expired or is invalid. Please request a new one."
    end
  end
end
