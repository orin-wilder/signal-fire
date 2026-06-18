class Totem < ApplicationRecord
  has_many :host_totem_assignments, dependent: :destroy
  has_many :hosts, through: :host_totem_assignments, source: :host_user
  has_many :events
  has_many :totem_favorites
  has_many :empty_totem_email_captures

  # Physical short code (Phase 6): a short numeric printed on the totem for typed
  # entry at /g/:code. String storage keeps leading zeros and lets length grow.
  SHORT_CODE_LENGTH = 2

  validates :name, presence: true
  validates :location, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/, message: "only lowercase letters, numbers, and hyphens" }
  validates :character_description, length: { maximum: 140 }, allow_blank: true
  validates :city_slug, presence: true
  validates :short_code, uniqueness: true, allow_blank: true,
    format: { with: /\A\d{2,}\z/, message: "must be at least 2 digits" }

  scope :active,             ->       { where(active: true) }
  scope :for_city,           ->(slug) { where(city_slug: slug) }
  scope :city_board_visible, ->       { active.where.not(character_description: [ nil, "" ]) }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }
  before_validation :generate_short_code, if: -> { short_code.blank? }

  def board_empty?
    return true unless active

    has_upcoming = events.active.publicly_visible.where.not(recurrence_rule: nil).exists? ||
                   events.active.publicly_visible.where(recurrence_rule: nil).where("start_time > ?", Time.current).exists?

    has_recent = events.active.publicly_visible.where("end_time > ? AND end_time < ?", 30.days.ago, Time.current).exists?

    !has_upcoming && !has_recent
  end

  def primary_host
    hosts.joins(:host_profile)
         .where.not(host_profiles: { host_story: nil })
         .first || hosts.first
  end

  def active_now_events
    now = Time.current
    window_start = now - Event::CHECKIN_WINDOW_AFTER_MINUTES.minutes
    window_end   = now + Event::CHECKIN_WINDOW_BEFORE_MINUTES.minutes

    events.active.publicly_visible
          .includes(host_user: :host_profile)
          .where("start_time <= ? AND end_time >= ?", window_end, window_start)
          .sort_by { |e|
            if e.start_time <= now && e.end_time >= now
              [0, e.start_time.to_i]
            elsif e.start_time > now
              [1, e.start_time.to_i]
            else
              [2, -e.end_time.to_i]
            end
          }
  end

  def upcoming_events
    window_end = Time.current + Event::CHECKIN_WINDOW_BEFORE_MINUTES.minutes
    events.active.publicly_visible.includes(host_user: :host_profile).reject(&:active_now?).select { |e| e.next_occurrence > window_end }.sort_by(&:next_occurrence)
  end

  # The "Earlier" rail: the few most-recent published one-time events that ended
  # very recently (last 24h), newest first. Kept short on purpose — the board is a
  # forward-looking surface. Recurring events never go "past" (always a next occ).
  def past_events(within: 24.hours, limit: 2)
    events.active.publicly_visible
          .where(recurrence_rule: nil)
          .where(end_time: within.ago...Time.current)
          .includes(host_user: :host_profile)
          .order(end_time: :desc)
          .limit(limit)
  end

  private

  def generate_slug
    base = name.parameterize
    candidate = base
    n = 2
    while Totem.where.not(id: id).exists?(slug: candidate)
      candidate = "#{base}-#{n}"
      n += 1
    end
    self.slug = candidate
  end

  # Mirrors generate_slug: random numeric code with a uniqueness-retry loop. Grows
  # a digit if the current length gets crowded so it can't spin forever.
  def generate_short_code
    length = SHORT_CODE_LENGTH
    attempts = 0
    loop do
      candidate = rand(10**length).to_s.rjust(length, "0")
      return self.short_code = candidate unless Totem.where.not(id: id).exists?(short_code: candidate)

      attempts += 1
      length += 1 if attempts >= 20
    end
  end
end
