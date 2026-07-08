class Api::V1::Auth::RegistrationsController < ActionController::API
  # Mass-signup guard; default with: raises → 429.
  rate_limit to: 15, within: 3.minutes, only: :create, store: RateLimitStore

  def create
    user = User.new(
      email: params[:email]&.downcase,
      password: params[:password],
      name: params[:name],
      auth_method: :email
    )

    if user.save
      token = JwtService.encode(user_id: user.id)
      AnalyticsService.identify(user.id, email: user.email, auth_method: user.auth_method, is_host: user.is_host)
      render json: { token: token, user: user_json(user) }, status: :created
    else
      render json: { error: user.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  private

  def user_json(user)
    user.slice(:id, :name, :email, :is_host, :is_admin)
  end
end
