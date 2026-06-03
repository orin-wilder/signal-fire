class Event < ApplicationRecord
  CHECKIN_WINDOW_BEFORE_MINUTES = 30
  CHECKIN_WINDOW_AFTER_MINUTES = 30

  belongs_to :totem
  belongs_to :host_user, class_name: "User"
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

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :recurrence_rule, format: {
    with: /\AFREQ=(WEEKLY|MONTHLY|DAILY|YEARLY)/,
    message: "must be a valid RRULE string"
  }, allow_nil: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :status, presence: true
  validate :end_time_after_start_time

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
end
