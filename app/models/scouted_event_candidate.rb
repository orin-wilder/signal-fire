class ScoutedEventCandidate < ApplicationRecord
  belongs_to :scout_run
  belongs_to :event, optional: true

  scope :active, -> { where(ignored: false) }

  def added_to_totem? = event_id.present?

  # Compose a start time (America/New_York) from the raw AI date/time strings.
  # Returns nil when the date is unparseable; callers default to a safe future time.
  def starts_at
    return nil if event_date.blank?

    time = event_time.presence || "18:00"
    Time.find_zone("America/New_York").parse("#{event_date} #{time}")
  rescue ArgumentError
    nil
  end
end
