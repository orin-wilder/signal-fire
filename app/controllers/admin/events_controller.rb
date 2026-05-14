class Admin::EventsController < Admin::ApplicationController
  include EventTimeAssembly

  before_action :set_event, only: [:edit, :update, :destroy]

  def index
    @events = Event.includes(:totem, host_user: :host_profile).order(start_time: :desc)

    if params[:q].present?
      q = "%#{params[:q]}%"
      @events = @events
        .joins(:totem, host_user: :host_profile)
        .where(
          "events.title ILIKE :q OR totems.name ILIKE :q OR users.name ILIKE :q OR host_profiles.display_name ILIKE :q",
          q: q
        )
    end
  end

  def new
    @event       = Event.new
    @hosts       = active_hosts
    @host_totems = host_totems_map(@hosts)
  end

  def create
    host = User.where(is_host: true).find(params.dig(:event, :host_user_id))

    @event = Event.new(event_params)
    @event.host_user        = host
    @event.created_by_admin = true

    if @event.save
      redirect_to admin_events_path, notice: "Event created."
    else
      @hosts       = active_hosts
      @host_totems = host_totems_map(@hosts)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @hosts       = active_hosts
    @host_totems = host_totems_map(@hosts)
  end

  def update
    host = User.where(is_host: true).find(params.dig(:event, :host_user_id))
    @event.host_user = host

    if @event.update(event_params)
      redirect_to admin_events_path, notice: "Event updated."
    else
      @hosts       = active_hosts
      @host_totems = host_totems_map(@hosts)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event.destroy
    redirect_to admin_events_path, notice: "Event deleted."
  end

  private

  def set_event
    @event = Event.includes(:totem, host_user: :host_profile).find(params[:id])
  end

  def active_hosts
    User.where(is_host: true)
        .joins(:host_profile)
        .where(host_profiles: { invite_status: "active" })
        .includes(:host_profile, host_totem_assignments: :totem)
        .order("host_profiles.display_name")
  end

  def host_totems_map(hosts)
    hosts.each_with_object({}) do |host, map|
      map[host.id.to_s] = host.host_totem_assignments
                              .map { |a| { id: a.totem_id, name: a.totem.name } }
    end
  end

  def event_params
    raw = params.require(:event).permit(
      :title, :totem_id, :recurrence_rule,
      :start_day_of_week, :start_date, :start_time_of_day, :end_time_of_day,
      :description, :community_norms,
      :chat_platform, :chat_url
    )
    assemble_times(raw)
  end
end
