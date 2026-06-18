class Admin::ScoutsController < Admin::ApplicationController
  def new
    @totems = Totem.order(:name)
  end

  def create
    totem = Totem.find(params[:totem_id])
    run = ScoutRun.create!(totem: totem, requested_by: current_user, status: "pending")
    EventScoutJob.perform_later(run.id)
    redirect_to admin_scout_path(run)
  end

  def show
    @run = ScoutRun.includes(candidates: :event).find(params[:id])
    @candidates = @run.candidates.active.order(:created_at) if @run.complete?
  end

  # Polled by the scout-status Stimulus controller while a run is pending.
  def status
    render json: { status: ScoutRun.find(params[:id]).status }
  end
end
