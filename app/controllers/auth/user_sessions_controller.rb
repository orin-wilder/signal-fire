class Auth::UserSessionsController < ApplicationController
  # Brute-force / magic-link-bombing guard (create covers both sign-in paths).
  rate_limit to: 10, within: 3.minutes, only: :create, store: RateLimitStore,
    with: -> { redirect_to sign_in_path, alert: "Too many attempts. Please wait a few minutes and try again." }

  def new
  end

  def new_magic_link
  end

  def create
    email = params[:email]&.strip&.downcase

    if params[:password].present?
      sign_in_with_password(email, params[:password])
    else
      sign_in_with_magic_link(email)
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to root_path
  end

  private

  def sign_in_with_password(email, password)
    user = User.find_by(email: email)

    if user&.authenticate(password)
      session[:user_id] = user.id
      redirect_to after_auth_path, notice: "Welcome back!"
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def sign_in_with_magic_link(email)
    user = User.find_by(email: email)

    if user
      user.generate_magic_link_token!
      UserMailer.magic_link_email(user).deliver_later
    end

    # Always show success to avoid email enumeration
    redirect_to sign_in_magic_link_path, notice: "If we have an account for that email, we've sent you a sign-in link."
  end
end
