class Admin::AnalyticsController < Admin::ApplicationController
  ALLOWED_RANGES = [ 7, 30, 90 ].freeze

  def index
    @range = params[:range].to_i
    @range = 30 unless ALLOWED_RANGES.include?(@range)
    since = @range.days.ago

    scoped = AnalyticsEvent.since(since)

    # ── Platform overview ──
    by_name = scoped.group(:name).count
    @totals = {
      scans:         by_name["totem_scan"]  || 0,
      board_views:   by_name["board_view"]  || 0,
      event_views:   by_name["event_view"]  || 0,
      calendar_adds: by_name["calendar_add"] || 0,
      shares:        by_name["event_share"] || 0,
      submissions:   by_name["event_submission"] || 0
    }
    @conversion_rate = conversion_rate(@totals[:submissions], @totals[:board_views])
    @unique_visitors = scoped.where.not(visitor_hash: nil).distinct.count(:visitor_hash)
    @check_ins  = CheckIn.where("checked_in_at >= ?", since).count
    @follows    = HostFollow.where("created_at >= ?", since).count
    @favorites  = TotemFavorite.where("created_at >= ?", since).count

    # ── Per-day series (grouped in app TZ; low volume, no groupdate gem) ──
    @daily_series = build_daily_series(scoped)

    # ── By totem ──
    @totem_rows = build_totem_rows(scoped, since)

    # ── By activity (event) ──
    @event_rows = build_event_rows(scoped, since)
  end

  private

  def build_daily_series(scoped)
    counts = Hash.new(0)
    scoped.pluck(:occurred_at).each do |t|
      counts[t.in_time_zone.to_date] += 1
    end
    start_date = (@range - 1).days.ago.in_time_zone.to_date
    today = Time.zone.today
    (start_date..today).map { |date| [ date, counts[date] ] }
  end

  def build_totem_rows(scoped, since)
    scans       = scoped.named("totem_scan").group(:totem_id).count
    boards      = scoped.named("board_view").group(:totem_id).count
    views       = scoped.named("event_view").group(:totem_id).count
    calendars   = scoped.named("calendar_add").group(:totem_id).count
    submissions = scoped.named("event_submission").group(:totem_id).count
    uniques     = scoped.where.not(visitor_hash: nil).group(:totem_id).distinct.count(:visitor_hash)
    check_ins   = CheckIn.joins(:event).where("checked_in_at >= ?", since).group("events.totem_id").count

    ids = (scans.keys + boards.keys + views.keys + calendars.keys + submissions.keys + check_ins.keys).compact.uniq
    totems = Totem.where(id: ids).index_by(&:id)

    ids.filter_map do |id|
      totem = totems[id]
      next unless totem

      board_views = boards[id] || 0
      subs        = submissions[id] || 0
      {
        totem:           totem,
        scans:           scans[id] || 0,
        board_views:     board_views,
        event_views:     views[id] || 0,
        calendar_adds:   calendars[id] || 0,
        submissions:     subs,
        conversion:      conversion_rate(subs, board_views),
        unique_visitors: uniques[id] || 0,
        check_ins:       check_ins[id] || 0
      }
    end.sort_by { |r| -(r[:scans] + r[:board_views] + r[:event_views]) }.first(25)
  end

  # Submissions as a share of board views, in [0.0, 1.0]. Nil when there's no
  # traffic to divide by (renders as "—" rather than a misleading 0%).
  def conversion_rate(submissions, board_views)
    return nil if board_views.to_i.zero?

    submissions.to_f / board_views
  end

  def build_event_rows(scoped, since)
    views     = scoped.named("event_view").group(:event_id).count
    calendars = scoped.named("calendar_add").group(:event_id).count
    shares    = scoped.named("event_share").group(:event_id).count
    check_ins = CheckIn.where("checked_in_at >= ?", since).group(:event_id).count

    ids = (views.keys + calendars.keys + shares.keys + check_ins.keys).compact.uniq
    events = Event.where(id: ids).includes(:totem).index_by(&:id)

    ids.filter_map do |id|
      event = events[id]
      next unless event

      {
        event:         event,
        event_views:   views[id] || 0,
        calendar_adds: calendars[id] || 0,
        shares:        shares[id] || 0,
        check_ins:     check_ins[id] || 0
      }
    end.sort_by { |r| -(r[:event_views] + r[:calendar_adds] + r[:shares] + r[:check_ins]) }.first(25)
  end
end
