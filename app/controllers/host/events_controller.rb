class Host::EventsController < Host::ApplicationController
  include EventTimeAssembly
  before_action :set_own_event, only: [:edit, :update, :destroy]
  before_action :set_totem_event, only: [:show]

  def index
    totem_ids = current_user.host_totem_assignments.pluck(:totem_id)
    @events = Event.where(totem_id: totem_ids)
                   .includes(:totem, :host_user, :anonymous_check_in_count, :check_ins)
                   .order(start_time: :desc)
  end

  def show
  end

  def new
    @event = Event.new
    @totems = host_totems
  end

  def create
    @event = Event.new(event_params)
    @event.host_user = current_user

    if @event.save
      AnalyticsService.track(
        "host_event_created",
        host_user_id: current_user.id,
        event_id: @event.id,
        totem_id: @event.totem_id,
        created_by_admin: @event.created_by_admin
      )
      redirect_to host_events_path, notice: "Event created."
    else
      @totems = host_totems
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @totems = host_totems
  end

  def update
    if @event.update(event_params)
      redirect_to host_events_path, notice: "Event updated."
    else
      @totems = host_totems
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event.destroy
    redirect_to host_events_path, notice: "Event deleted."
  end

  private

  def set_own_event
    totem_ids = current_user.host_totem_assignments.pluck(:totem_id)
    @event = Event.find_by!(id: params[:id], host_user_id: current_user.id, totem_id: totem_ids)
  end

  def set_totem_event
    totem_ids = current_user.host_totem_assignments.pluck(:totem_id)
    @event = Event.find_by!(id: params[:id], totem_id: totem_ids)
  end

  def host_totems
    Totem.joins(:host_totem_assignments)
         .where(host_totem_assignments: { host_user_id: current_user.id })
         .order(:name)
  end

  def event_params
    raw = params.require(:event).permit(
      :title, :totem_id, :recurrence_rule,
      :start_day_of_week, :start_date, :start_time_of_day, :end_time_of_day,
      :description, :short_description, :community_norms,
      :chat_platform, :chat_url, :source_url
    )
    assemble_times(raw)
  end

end
