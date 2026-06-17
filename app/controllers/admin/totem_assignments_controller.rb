class Admin::TotemAssignmentsController < Admin::ApplicationController
  # Super-admin assignment of any user to any totem with any role (incl. totem_admin
  # for non-host users — the host-edit page only manages role: host).
  def new
    @users  = User.order(:email)
    @totems = Totem.order(:location, :name)
  end

  def create
    user  = User.find(params[:user_id])
    totem = Totem.find(params[:totem_id])
    role  = params[:role].presence_in(HostTotemAssignment.roles.keys) || "host"

    assignment = HostTotemAssignment.find_or_initialize_by(host_user_id: user.id, totem_id: totem.id)
    assignment.role                 = role
    assignment.assigned_by_admin_id = current_user.id
    assignment.assigned_at          ||= Time.current
    assignment.save!

    redirect_to new_admin_totem_assignment_path,
      notice: "#{user.email} is now #{role.humanize.downcase} on #{totem.name}."
  rescue ActiveRecord::RecordInvalid => e
    @users  = User.order(:email)
    @totems = Totem.order(:location, :name)
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :new, status: :unprocessable_entity
  end
end
