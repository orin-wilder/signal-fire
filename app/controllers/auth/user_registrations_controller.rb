class Auth::UserRegistrationsController < ApplicationController
  # Mass-signup / magic-link email guard.
  rate_limit to: 10, within: 15.minutes, only: :create, store: RateLimitStore,
    with: -> { redirect_to sign_up_path, alert: "Too many attempts. Please wait a few minutes and try again." }

  def new
    @user = User.new
  end

  def create
    email    = params[:email]&.strip&.downcase
    name     = params[:name]&.strip
    password = params[:password]

    if password.present?
      create_with_password(email, name, password)
    else
      create_with_magic_link(email, name)
    end
  end

  private

  def create_with_password(email, name, password)
    existing = User.find_by(email: email)

    if existing
      # Account exists — send them to sign in instead
      @user = existing
      @user.errors.add(:email, "already has an account — please sign in")
      render_error and return
    end

    @user = User.new(email: email, name: name, password: password, auth_method: :email)
    @user.errors.add(:name, "can't be blank") if name.blank?

    if @user.errors.any? || !@user.valid?
      render_error and return
    end

    @user.save!
    session[:user_id] = @user.id
    render_success(via_password: true)
  end

  def create_with_magic_link(email, name)
    existing = User.find_by(email: email)

    if existing
      existing.generate_magic_link_token!
      UserMailer.magic_link_email(existing).deliver_later
      render_success(via_password: false) and return
    end

    @user = User.new(email: email, name: name, auth_method: :email)
    @user.errors.add(:name, "can't be blank") if name.blank?

    if @user.errors.any? || !@user.valid?
      render_error and return
    end

    @user.save!
    @user.generate_magic_link_token!
    UserMailer.magic_link_email(@user).deliver_later
    render_success(via_password: false)
  end

  def render_success(via_password:)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            "account-signup-modal-content",
            partial: "shared/account_signup_success",
            locals: { via_password: via_password, container_id: "account-signup-modal-content" }
          ),
          turbo_stream.replace(
            "account-signup-form-container",
            partial: "shared/account_signup_success",
            locals: { via_password: via_password, container_id: "account-signup-form-container" }
          ),
          turbo_stream.remove("account-signup-banner")
        ]
      end
      format.html do
        if via_password
          redirect_to after_auth_path, notice: "Welcome to Signal Fire!"
        else
          redirect_to sign_up_path, notice: "Check your email for a sign-in link."
        end
      end
    end
  end

  def render_error
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "account-signup-form-container",
          partial: "shared/account_signup_form",
          locals: { user: @user }
        )
      end

      format.html { render :new, status: :unprocessable_entity }
    end
  end
end
