class NotificationDelivery < ApplicationRecord
  belongs_to :user
  belongs_to :event

  enum :notification_type, {
    new_event:      "new_event",
    reminder:       "reminder",
    cancelled:      "cancelled",
    first_stranger: "first_stranger",
    weekly_digest:  "weekly_digest"
  }
  enum :source_type, {
    host_follow:    "host_follow",
    totem_favorite: "totem_favorite",
    direct:         "direct"
  }

  validates :notification_type, presence: true
  validates :source_type, presence: true
  # occurrence_date is nil for once-ever types (new_event, cancelled,
  # first_stranger); the backing index is NULLS NOT DISTINCT so nil rows still
  # dedup at the database level.
  validates :user_id, uniqueness: { scope: [ :event_id, :notification_type, :occurrence_date ] }
end
