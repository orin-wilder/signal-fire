class PreEventReminderJob < ApplicationJob
  include EventNotificationFanout

  queue_as :default

  # occurrence_date scopes the dedup index to this occurrence, so weekly
  # reminders after the first aren't suppressed. Older queued jobs serialized
  # without it fall back to the occurrence the reminder is firing for.
  def perform(event_id, occurrence_date = nil)
    event = Event.find_by(id: event_id)
    return unless event&.active?

    occurrence = event.next_occurrence
    occurrence_date ||= occurrence.to_date

    reminder_recipients_for(event).each do |recipient|
      deliver_to(
        user: recipient[:user],
        event: event,
        notification_type: :reminder,
        source_type: recipient[:source_type],
        occurrence_date: occurrence_date,
        title: "Starting soon: #{event.title}",
        body: "#{event.title} starts in about 1 hour at #{event.totem.name}"
      )
    end

    # Chain the next reminder for weekly events
    schedule_next_reminder(event, occurrence) if event.weekly?
  end

  private

  def schedule_next_reminder(event, current_occurrence)
    next_occurrence = current_occurrence + 1.week
    fire_at = next_occurrence - 1.hour
    PreEventReminderJob.set(wait_until: fire_at).perform_later(event.id, next_occurrence.to_date)
  end
end
