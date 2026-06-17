class Event < ApplicationRecord
  CHECKIN_WINDOW_BEFORE_MINUTES = 30
  CHECKIN_WINDOW_AFTER_MINUTES = 30

  # Fallback span for board submissions / scouted events that carry no explicit
  # end time (mirrors Admin::PromoteScoutedEvent::DEFAULT_DURATION). Keeps
  # window_state/active_now?/upcoming_events working without a host-entered value.
  DEFAULT_DURATION = 2.hours

  belongs_to :totem
  # Optional since Phase 2: board submissions (anonymous/visitor) have no host.
  belongs_to :host_user, class_name: "User", optional: true
  has_many :check_ins, dependent: :destroy
  has_one :anonymous_check_in_count, dependent: :destroy
  has_many :notification_deliveries, dependent: :destroy

  enum :chat_platform, {
    whatsapp: "whatsapp",
    discord: "discord",
    telegram: "telegram",
    signal: "signal",
    groupme: "groupme",
    slack: "slack"
  }
  enum :status, { active: "active", cancelled: "cancelled" }

  # provenance/approval_state are prefixed to avoid clobbering the status enum's
  # bare active?/cancelled? predicates and to read clearly at call sites.
  enum :provenance, {
    host: "host",
    admin: "admin",
    scouted: "scouted",
    board_submission: "board_submission"
  }, prefix: true
  enum :approval_state, { published: "published", pending_review: "pending_review" }, prefix: true

  # The single public-visibility gate. Threaded through every public read path
  # so unverified/pending content never reaches a QR/board surface.
  scope :publicly_visible, -> { where(approval_state: "published") }

  # Upcoming events at OTHER totems in the same city, soonest first. next_occurrence
  # is computed in Ruby (IceCube), so narrow in SQL then sort/limit in Ruby — same
  # shape as Totem#upcoming_events. Honors the publicly_visible gate.
  def self.nearby_upcoming(city_slug:, excluding_totem_id: nil, limit: 8, within: 7.days)
    now = Time.current
    scope = active.publicly_visible
              .joins(:totem).merge(Totem.active.for_city(city_slug))
              .includes(:totem, host_user: :host_profile)
    scope = scope.where.not(totem_id: excluding_totem_id) if excluding_totem_id

    scope.select { |e| (now...(now + within)).cover?(e.next_occurrence) }
         .sort_by(&:next_occurrence)
         .first(limit)
  end

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :recurrence_rule, format: {
    with: /\AFREQ=(WEEKLY|MONTHLY|DAILY|YEARLY)/,
    message: "must be a valid RRULE string"
  }, allow_nil: true
  validates :start_time, presence: true
  # Host/admin events must carry an explicit end time (the form requires it);
  # board submissions / scouted events fall back to DEFAULT_DURATION below.
  validates :end_time, presence: true, if: -> { provenance_host? || provenance_admin? }
  validates :status, presence: true
  validates :source_url, allow_blank: true,
    format: { with: %r{\Ahttps?://}i, message: "must start with http:// or https://" }
  validates :submitter_email, allow_blank: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :short_description, length: { maximum: 160 }, allow_blank: true
  validate :end_time_after_start_time

  before_validation :default_end_time
  before_validation :generate_slug, if: -> { slug.blank? && title.present? }
  after_create :enqueue_new_event_jobs
  after_update :enqueue_cancellation_job, if: -> { saved_change_to_status?(to: "cancelled") }

  def active_now?
    window_start = start_time - CHECKIN_WINDOW_BEFORE_MINUTES.minutes
    window_end = end_time + CHECKIN_WINDOW_AFTER_MINUTES.minutes
    Time.current.between?(window_start, window_end)
  end

  def window_state
    return :cancelled if cancelled?

    now = Time.current
    window_before_start = start_time - CHECKIN_WINDOW_BEFORE_MINUTES.minutes
    window_after_end    = end_time   + CHECKIN_WINDOW_AFTER_MINUTES.minutes

    if now < window_before_start   then :before
    elsif now < start_time         then :starting_soon
    elsif now <= end_time          then :happening_now
    elsif now <= window_after_end  then :just_ended
    else                                :past
    end
  end

  def publicly_visible? = approval_state_published?

  def one_time?  = recurrence_rule.blank?
  def recurring? = recurrence_rule.present?

  def weekly?
    recurring? &&
      recurrence_rule.include?("FREQ=WEEKLY") &&
      !recurrence_rule.match?(/INTERVAL=[2-9]/)
  end

  def next_occurrence(after: Time.current)
    return start_time if one_time?

    schedule = IceCube::Schedule.new(start_time)
    schedule.add_recurrence_rule(IceCube::Rule.from_ical(recurrence_rule))
    schedule.next_occurrence(after - 1.second)&.to_time || start_time
  end

  def recurrence_label
    return nil if one_time?

    schedule = IceCube::Schedule.new(start_time)
    schedule.add_recurrence_rule(IceCube::Rule.from_ical(recurrence_rule))
    schedule.to_s
  rescue StandardError
    "Recurring"
  end

  private

  def enqueue_new_event_jobs
    # Only published, host-authored events notify followers/favorites. This keeps
    # admin-curated and AI-sourced (scouted/pending) events out of the push
    # fan-out entirely — no low-content or unverified-content notifications.
    return unless approval_state_published? && provenance_host?

    NewEventNotificationJob.perform_later(id)
    fire_at = next_occurrence - 1.hour
    PreEventReminderJob.set(wait_until: fire_at).perform_later(id)
  end

  def enqueue_cancellation_job
    EventCancellationNotificationJob.perform_later(id)
  end

  def generate_slug
    base = "#{totem&.slug}-#{title.parameterize}"
    candidate = base
    n = 2
    while Event.where.not(id: id).exists?(slug: candidate)
      candidate = "#{base}-#{n}"
      n += 1
    end
    self.slug = candidate
  end

  def end_time_after_start_time
    return unless start_time && end_time
    errors.add(:end_time, "must be after start time") if end_time <= start_time
  end

  # Board submissions / scouted events arrive without an end time; give them a
  # default span so the lifecycle methods work. Host/admin events are left blank
  # on purpose so the presence validation above flags a missing value.
  def default_end_time
    return if end_time.present? || start_time.blank?
    return if provenance_host? || provenance_admin?

    self.end_time = start_time + DEFAULT_DURATION
  end
end
