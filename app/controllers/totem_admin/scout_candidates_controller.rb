class TotemAdmin::ScoutCandidatesController < TotemAdmin::ApplicationController
  before_action :set_candidate

  # Promote an AI-found candidate to a pending_review Event on the totem (lands
  # off public boards until the moderator publishes it). Reuses the admin promoter.
  def add_to_totem
    event = Admin::PromoteScoutedEvent.to_totem(@candidate, host_user: current_user)
    if event.persisted?
      @candidate.update!(event: event)
      back "Added to #{event.totem.name} — pending your review."
    else
      back_alert "Couldn't add: #{event.errors.full_messages.to_sentence}"
    end
  end

  def ignore
    @candidate.update!(ignored: true)
    back "Dismissed."
  end

  private

  # Scope to candidates whose scout run is on a totem this user moderates.
  def set_candidate
    @candidate = ScoutedEventCandidate
                   .joins(:scout_run)
                   .where(scout_runs: { totem_id: current_user.moderated_totem_ids })
                   .find(params[:id])
  end

  def back(notice)
    redirect_back fallback_location: totem_admin_scout_path(@candidate.scout_run), notice: notice
  end

  def back_alert(alert)
    redirect_back fallback_location: totem_admin_scout_path(@candidate.scout_run), alert: alert
  end
end
