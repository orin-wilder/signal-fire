class Auth::UserMagicLinksController < ApplicationController
  # Token brute-force guard.
  rate_limit to: 30, within: 15.minutes, only: :verify, store: RateLimitStore,
    with: -> { redirect_to sign_in_path, alert: "Too many attempts. Please wait a few minutes and try again." }

  def verify
    user = User.find_by(magic_link_token: params[:token])

    if user&.magic_link_token_valid?
      user.consume_magic_link_token!
      session[:user_id] = user.id
      redirect_to after_auth_path, notice: "Welcome to Signal Fire!"
    else
      redirect_to sign_in_path, alert: "That sign-in link has expired or is invalid. Please request a new one."
    end
  end
end
