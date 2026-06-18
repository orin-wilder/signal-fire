class TotemAdmin::EventsController < TotemAdmin::ApplicationController
  include EventTimeAssembly

  before_action :set_event, only: [:edit, :update, :destroy, :publish]

  # The delegated moderation queue: pending submissions on the totems this user
  # moderates, soonest first.
  def index
    @events = Event.where(approval_state: "pending_review", totem_id: current_user.moderated_totem_ids)
                   .includes(:totem)
                   .order(start_time: :asc)
  end

  def edit
  end

  def update
    if @event.update(event_params)
      redirect_to totem_admin_events_path, notice: "Event updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    title = @event.title
    @event.destroy
    redirect_to totem_admin_events_path, notice: "Removed “#{title}.”"
  end

  # The delegated approval gate — flips pending_review → published for events on
  # totems this user moderates.
  def publish
    @event.update!(approval_state: "published")
    redirect_to totem_admin_events_path, notice: "Published “#{@event.title}.”"
  end

  private

  # Scope every member action to moderated totems. A moderator can never touch an
  # event on a totem they don't moderate — find raises RecordNotFound (404).
  def set_event
    @event = Event.where(totem_id: current_user.moderated_totem_ids).find(params[:id])
  end

  def event_params
    raw = params.require(:event).permit(
      :title, :short_description, :source_url, :recurrence_rule,
      :start_date, :start_time_of_day, :end_time_of_day
    )
    assemble_times(raw)
  end
end
