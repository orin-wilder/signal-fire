require "test_helper"

class PreEventReminderJobTest < ActiveSupport::TestCase
  EXPECTED_RECIPIENT_COUNT = 3

  setup do
    @event = events(:upcoming_event)
  end

  test "creates reminder NotificationDeliveries for all recipients" do
    assert_difference "NotificationDelivery.where(notification_type: 'reminder').count",
                      EXPECTED_RECIPIENT_COUNT do
      PreEventReminderJob.new.perform(@event.id)
    end
  end

  test "subscriber_user reminder attributed to host_follow" do
    PreEventReminderJob.new.perform(@event.id)
    delivery = NotificationDelivery.find_by(
      user: users(:subscriber_user), event: @event, notification_type: "reminder"
    )
    assert_not_nil delivery
    assert delivery.host_follow?
  end

  test "does not create duplicate deliveries on retry" do
    PreEventReminderJob.new.perform(@event.id)
    count = NotificationDelivery.count
    PreEventReminderJob.new.perform(@event.id)
    assert_equal count, NotificationDelivery.count
  end

  test "skips all deliveries for cancelled event" do
    @event.update_column(:status, "cancelled")
    assert_no_difference "NotificationDelivery.count" do
      PreEventReminderJob.new.perform(@event.id)
    end
  end

  test "does not enqueue next reminder for one-time event" do
    assert_no_enqueued_jobs only: PreEventReminderJob do
      PreEventReminderJob.new.perform(@event.id)
    end
  end

  test "enqueues next reminder for weekly event with the next occurrence date" do
    weekly = events(:weekly_event)
    expected_date = (weekly.next_occurrence + 1.week).to_date
    assert_enqueued_with(job: PreEventReminderJob, args: [ weekly.id, expected_date ]) do
      PreEventReminderJob.new.perform(weekly.id)
    end
  end

  # The old dedup ignored occurrences, so a weekly reminder fired once ever;
  # each occurrence must now notify (and stay idempotent within an occurrence).
  test "weekly reminders fire for each occurrence instead of once ever" do
    weekly = events(:weekly_event)
    # subscriber_user follows host_user with notify_reminder and, with this
    # check-in, is a prior attendee at this totem — the recurring-event filter
    CheckIn.create!(user: users(:subscriber_user), event: events(:upcoming_event))

    first_occurrence = weekly.next_occurrence.to_date

    assert_difference "NotificationDelivery.where(notification_type: 'reminder').count", 1 do
      PreEventReminderJob.new.perform(weekly.id, first_occurrence)
    end

    assert_no_difference "NotificationDelivery.count" do
      PreEventReminderJob.new.perform(weekly.id, first_occurrence)
    end

    assert_difference "NotificationDelivery.where(notification_type: 'reminder').count", 1 do
      PreEventReminderJob.new.perform(weekly.id, first_occurrence + 7)
    end
  end

  test "silently returns when event is not found" do
    assert_nothing_raised { PreEventReminderJob.new.perform(-1) }
  end
end
