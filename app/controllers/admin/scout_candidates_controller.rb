class Admin::ScoutCandidatesController < Admin::ApplicationController
  before_action :set_candidate

  def add_to_totem
    event = Admin::PromoteScoutedEvent.to_totem(@candidate, host_user: current_user)
    if event.persisted?
      @candidate.update!(event: event)
      back "Added to #{event.totem.name} totem board — pending review."
    else
      back_alert "Couldn't add to totem: #{event.errors.full_messages.to_sentence}"
    end
  end

  def add_to_bulletin
    post = Admin::PromoteScoutedEvent.to_bulletin(@candidate)
    if post.persisted?
      @candidate.update!(bulletin_post: post)
      back "Added to #{post.totem.name} bulletin board — pending review."
    else
      back_alert "Couldn't add to bulletin: #{post.errors.full_messages.to_sentence}"
    end
  end

  def ignore
    @candidate.update!(ignored: true)
    back "Dismissed."
  end

  private

  def set_candidate
    @candidate = ScoutedEventCandidate.find(params[:id])
  end

  def back(notice)
    redirect_back fallback_location: admin_scout_path(@candidate.scout_run), notice: notice
  end

  def back_alert(alert)
    redirect_back fallback_location: admin_scout_path(@candidate.scout_run), alert: alert
  end
end
