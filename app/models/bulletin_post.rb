class BulletinPost < ApplicationRecord
  CADENCES = %w[weekly monthly].freeze

  # Provenance, shown in admin only for now. New values append here.
  SOURCE_LABELS = {
    "public_submission" => "Visitor",
    "admin_added"       => "Admin",
    "scouted"           => "Scouted"
  }.freeze

  belongs_to :totem

  scope :approved, -> { where(status: "approved") }
  scope :pending,  -> { where(status: "pending") }

  # Upcoming: approved events still in the future, plus recurring posts which
  # stay upcoming permanently (recurrence is display-only — no schedule engine, §8).
  # Soonest first.
  scope :upcoming, lambda {
    approved.where("starts_at >= :now OR recurring = :yes", now: Time.current, yes: true)
            .order(starts_at: :asc)
  }

  # Past: approved, one-time events whose start has passed. Most-recent first.
  scope :past, lambda {
    approved.where(recurring: false).where("starts_at < ?", Time.current)
            .order(starts_at: :desc)
  }

  validates :title, presence: true, length: { maximum: 80 }
  validates :description, presence: true, length: { maximum: 160 }
  validates :starts_at, presence: true
  validate  :starts_at_in_future, on: :create
  validates :recurrence_cadence, inclusion: { in: CADENCES }, if: :recurring?
  validates :source_url, allow_blank: true,
    format: { with: %r{\Ahttps?://}i, message: "must start with http:// or https://" }

  def source_label
    SOURCE_LABELS.fetch(source, source.to_s.titleize)
  end

  private

  def starts_at_in_future
    return if starts_at.blank?

    errors.add(:starts_at, "needs to be in the future") if starts_at <= Time.current
  end
end
