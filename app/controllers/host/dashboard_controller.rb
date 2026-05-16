class Host::DashboardController < Host::ApplicationController
  def show
    totem_ids = current_user.host_totem_assignments.pluck(:totem_id)
    @totems = Totem.where(id: totem_ids).order(:name)

    filter_ids = if params[:totem_id].present?
      [params[:totem_id].to_i] & totem_ids
    else
      totem_ids
    end

    now = Time.current

    @upcoming_events = Event.where(totem_id: filter_ids)
                            .active
                            .where("end_time >= ?", now)
                            .includes(:totem, :host_user, :anonymous_check_in_count, :check_ins)
                            .order(:start_time)

    @past_events = Event.where(totem_id: filter_ids)
                        .where("end_time < ?", now)
                        .includes(:totem, :host_user, :anonymous_check_in_count, :check_ins)
                        .order(end_time: :desc)
                        .limit(20)

    @follower_count = HostFollow.where(host_user_id: current_user.id).count

    totem_event_ids = Event.where(totem_id: totem_ids).pluck(:id)
    @first_timers_this_month = CheckIn
      .where(event_id: totem_event_ids)
      .group(:user_id)
      .having("MIN(check_ins.created_at) >= ?", Time.current.beginning_of_month)
      .count
      .size

    week_start = now.beginning_of_week
    week_end   = now.end_of_week
    event_ids_this_week = Event.where(totem_id: totem_ids)
                               .where(start_time: week_start..week_end)
                               .pluck(:id)

    auth_count = CheckIn.where(event_id: event_ids_this_week).count
    anon_count = AnonymousCheckInCount.where(event_id: event_ids_this_week).sum(:count)
    @check_ins_this_week = auth_count + anon_count
  end
end
