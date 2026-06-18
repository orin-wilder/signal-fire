class TotemAdmin::ScoutsController < TotemAdmin::ApplicationController
  before_action :set_run, only: [:show, :status]

  # Delegated AI event discovery: a moderator can scout only the totems they
  # moderate. Mirrors Admin::ScoutsController, scoped to moderated_totem_ids.
  def new
    @totems = moderated_totems
  end

  def create
    totem = Totem.where(id: current_user.moderated_totem_ids).find(params[:totem_id])
    run = ScoutRun.create!(totem: totem, requested_by: current_user, status: "pending")
    EventScoutJob.perform_later(run.id)
    redirect_to totem_admin_scout_path(run)
  end

  def show
    @candidates = @run.candidates.active.order(:created_at) if @run.complete?
  end

  # Polled by the scout-status Stimulus controller while a run is pending.
  def status
    render json: { status: @run.status }
  end

  private

  # Scope to runs on totems this user moderates — 404 otherwise.
  def set_run
    @run = ScoutRun.where(totem_id: current_user.moderated_totem_ids)
                   .includes(candidates: :event)
                   .find(params[:id])
  end
end
