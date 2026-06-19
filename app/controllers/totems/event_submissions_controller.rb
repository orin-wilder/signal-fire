class Totems::EventSubmissionsController < ApplicationController
  before_action :set_totem

  # Per-IP spam control for the anonymous public path. Trusted users (auto-publishers)
  # are exempt. Fixed-window throttle backed by Rails.cache — replaces the old board's
  # "a human reviews everything" as the only line of defense.
  THROTTLE_LIMIT  = 5
  THROTTLE_WINDOW = 1.hour

  # POST /t/:slug/events — the unified submission funnel. Who is submitting decides
  # whether the event publishes immediately or lands in the review queue.
  def create
    @event = build_event

    if throttled?
      @event.errors.add(:base, "You've added several events recently. Give it a little while before adding more.")
      return render_rejected
    end

    if @event.save
      record_submission!
      respond_to do |format|
        format.turbo_stream # create.turbo_stream.erb → swap form for success
        format.html { redirect_to totem_board_path(@totem.slug), notice: submission_notice }
      end
    else
      render_rejected
    end
  end

  private

  def set_totem
    @totem = Totem.find_by!(slug: params[:slug])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  # The role-based create branch (UNIFIED_EVENT_FUNNEL_PLAN.md Phase 3). Provenance /
  # approval_state / host_user are set here, never mass-assigned, so a submitter can't
  # publish their own content or own an event they shouldn't.
  def build_event
    event = Event.new(event_params)
    event.totem = @totem

    if current_user&.can_auto_publish_on?(@totem)
      event.host_user      = current_user
      event.provenance     = current_user.is_admin? ? :admin : :host
      event.approval_state = :published
    else
      # Anonymous OR signed-in non-privileged: keep host_user nil (don't let a
      # non-host own an event or trip the notification gate); record attribution.
      event.host_user       = nil
      event.provenance      = :board_submission
      event.approval_state  = :pending_review
      event.submitter_ip    = request.remote_ip
      event.submitter_email = params.dig(:event, :submitter_email).presence
    end

    # The public quick-add form only collects a start; give every submission a
    # default span so host/admin auto-publishes satisfy the end_time validation too.
    event.end_time = event.start_time + Event::DEFAULT_DURATION if event.start_time && event.end_time.blank?
    event
  end

  def event_params
    permitted = params.require(:event).permit(:title, :short_description, :source_url)
    permitted[:start_time]      = compose_start_time(params.dig(:event, :date), params.dig(:event, :time))
    permitted[:recurrence_rule] = recurrence_rule_from_params
    permitted
  end

  def compose_start_time(date, time)
    return nil if date.blank? || time.blank?

    Time.find_zone("America/New_York").parse("#{date} #{time}")
  rescue ArgumentError
    nil
  end

  def recurrence_rule_from_params
    return nil unless ActiveModel::Type::Boolean.new.cast(params.dig(:event, :recurring))

    case params.dig(:event, :recurrence_cadence)
    when "weekly"  then "FREQ=WEEKLY"
    when "monthly" then "FREQ=MONTHLY"
    end
  end

  def submission_notice
    @event.approval_state_published? ? "Event added to the board." : "Thanks — we'll take a look."
  end

  def render_rejected
    respond_to do |format|
      format.turbo_stream { render :create, status: :unprocessable_entity }
      format.html do
        redirect_to totem_board_path(@totem.slug),
          alert: @event.errors.full_messages.to_sentence.presence || "We couldn't add that — give it another try."
      end
    end
  end

  # ── Throttle ────────────────────────────────────────────────────────────────

  def throttled?
    return false if current_user&.can_auto_publish_on?(@totem)

    submission_count >= THROTTLE_LIMIT
  end

  def record_submission!
    return if current_user&.can_auto_publish_on?(@totem)

    Rails.cache.write(throttle_key, submission_count + 1, expires_in: THROTTLE_WINDOW)
  rescue StandardError => e
    # Spam control must never block a submission. If the cache backend is
    # unreachable (e.g. the Solid Cache database isn't provisioned), fail open.
    Rails.logger.warn("[event_submission] throttle write failed: #{e.class}: #{e.message}")
  end

  def submission_count
    Rails.cache.read(throttle_key).to_i
  rescue StandardError => e
    # Treat a cache read failure as "no prior submissions" so the public funnel
    # degrades to unthrottled rather than 500ing. See record_submission! above.
    Rails.logger.warn("[event_submission] throttle read failed: #{e.class}: #{e.message}")
    0
  end

  def throttle_key
    "event_submission:#{request.remote_ip}"
  end
end
