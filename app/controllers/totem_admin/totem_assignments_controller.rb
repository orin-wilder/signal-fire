class TotemAdmin::TotemAssignmentsController < TotemAdmin::ApplicationController
  before_action :set_totem, only: [:create]

  # Form to invite/assign a host to one of the totems this admin moderates.
  def new
    @totems = moderated_totems
  end

  # Delegated host invite — scoped to the admin's moderated totems. Reuses the
  # super-admin InviteHostService for brand-new accounts; assigns existing users in place.
  def create
    name  = params[:name].to_s.strip
    email = params[:email].to_s.strip.downcase

    user = User.find_by(email: email)
    user ||= Admin::InviteHostService.new(name: name, email: email).call

    HostTotemAssignment.find_or_create_by!(host_user_id: user.id, totem_id: @totem.id) do |a|
      a.role                 = :host
      a.assigned_by_admin_id = current_user.id
      a.assigned_at          = Time.current
    end

    redirect_to totem_admin_totems_path, notice: "#{email} can now host on #{@totem.name}."
  rescue ActiveRecord::RecordInvalid => e
    @totems = moderated_totems
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end

  private

  # Guard: the target totem must be one the current user moderates.
  def set_totem
    @totem = Totem.find_by(id: params[:totem_id])
    unless @totem && current_user.moderated_totem_ids.include?(@totem.id)
      redirect_to totem_admin_totems_path, alert: "You can't manage hosts on that totem."
    end
  end
end
