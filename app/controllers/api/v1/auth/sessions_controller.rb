class Api::V1::Auth::SessionsController < ActionController::API
  # Credential-stuffing guard; default with: raises → 429.
  rate_limit to: 15, within: 3.minutes, only: :create, store: RateLimitStore

  def create
    user = User.find_by(email: params[:email]&.downcase)

    if user&.authenticate(params[:password])
      token = JwtService.encode(user_id: user.id)
      AnalyticsService.identify(user.id, email: user.email, auth_method: user.auth_method, is_host: user.is_host)
      render json: { token: token, user: user_json(user) }
    else
      render json: { error: "Invalid email or password." }, status: :unauthorized
    end
  end

  def destroy
    # JWT is stateless — client discards the token. Nothing to do server-side.
    head :no_content
  end

  private

  def user_json(user)
    user.slice(:id, :name, :email, :is_host, :is_admin)
  end
end
