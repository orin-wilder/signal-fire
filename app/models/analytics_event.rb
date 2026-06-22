# Append-only, cookieless traffic log. One row per "soft" signal (scan, view,
# calendar add, share) recorded via AnalyticsRecording#record_analytics_event.
# Read by Admin::AnalyticsController. Check-ins / follows / favorites are NOT
# stored here — they already live in their own tables.
class AnalyticsEvent < ApplicationRecord
  belongs_to :totem, optional: true
  belongs_to :event, optional: true
  belongs_to :user, optional: true

  # The signal names this table records. Keep in sync with the call sites.
  RECORDED_NAMES = %w[totem_scan board_view event_view calendar_add event_share].freeze

  validates :name, presence: true

  scope :since, ->(time) { where("occurred_at >= ?", time) }
  scope :named, ->(name) { where(name: name) }
end
