class Admin::HostsController < Admin::ApplicationController
  before_action :set_host, only: [:edit, :update, :destroy, :deactivate, :activate]

  def index
    @hosts = User.where(is_host: true)
                 .eager_load(:host_profile, host_totem_assignments: :totem)
                 .order("host_profiles.invited_at DESC")

    @hosts = @hosts.where(host_profiles: { invite_status: params[:status] }) if params[:status].present?

    host_ids = @hosts.map(&:id)
    @event_counts = Event.where(host_user_id: host_ids).group(:host_user_id).count
  end

  def new
  end

  def create
    Admin::InviteHostService.new(name: params[:name], email: params[:email]).call
    redirect_to admin_hosts_path, notice: "Invite sent to #{params[:email]}."
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end

  def edit
    @all_totems         = Totem.order(:location, :name)
    @assigned_totem_ids = @host.host_totem_assignments.pluck(:totem_id)
    @assigned_roles     = @host.host_totem_assignments.pluck(:totem_id, :role).to_h
  end

  def update
    @host.name = host_params[:name]
    @host.email = host_params[:email]
    @host.host_profile.display_name = host_params[:name]
    @host.host_profile.host_story = host_params[:host_story] if host_params.key?(:host_story)

    selected_ids = Array(host_params[:totem_ids]).map(&:to_i).reject(&:zero?)

    ActiveRecord::Base.transaction do
      @host.save!
      @host.host_profile.save!
      sync_totem_assignments(selected_ids, host_params[:totem_roles])
    end

    redirect_to admin_hosts_path, notice: "Host updated."
  rescue ActiveRecord::RecordInvalid => e
    @all_totems         = Totem.order(:location, :name)
    @assigned_totem_ids = @host.host_totem_assignments.pluck(:totem_id)
    @assigned_roles     = @host.host_totem_assignments.pluck(:totem_id, :role).to_h
    flash.now[:alert]   = e.record.errors.full_messages.to_sentence
    render :edit, status: :unprocessable_entity
  end

  def destroy
    if Event.where(host_user_id: @host.id).exists?
      redirect_to admin_hosts_path,
        alert: "Cannot delete #{@host.name} — they have events. Delete or reassign their events first."
      return
    end

    name = @host.name
    @host.destroy
    redirect_to admin_hosts_path, notice: "#{name} deleted."
  end

  def deactivate
    @host.host_profile.update!(invite_status: :deactivated)
    redirect_to admin_hosts_path, notice: "#{@host.name} deactivated."
  end

  def activate
    @host.host_profile.update!(invite_status: :active)
    redirect_to admin_hosts_path, notice: "#{@host.name} reactivated."
  end

  private

  def set_host
    @host = User.where(is_host: true).includes(:host_profile, :host_totem_assignments).find(params[:id])
  end

  def host_params
    params.require(:host).permit(:name, :email, :host_story, totem_ids: [], totem_roles: {})
  end

  # Upsert an assignment (with per-totem role) for each selected totem; destroy deselected.
  def sync_totem_assignments(totem_ids, totem_roles = {})
    roles       = (totem_roles || {}).to_h
    current     = @host.host_totem_assignments.index_by(&:totem_id)

    totem_ids.each do |tid|
      role = roles[tid.to_s].presence_in(HostTotemAssignment.roles.keys) || "host"

      if (assignment = current[tid])
        assignment.update!(role: role)
      else
        @host.host_totem_assignments.create!(
          totem_id:             tid,
          role:                 role,
          assigned_by_admin_id: current_user.id,
          assigned_at:          Time.current
        )
      end
    end

    @host.host_totem_assignments.where(totem_id: current.keys - totem_ids).destroy_all
  end
end
