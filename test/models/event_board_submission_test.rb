require "test_helper"

# Phase 2 (unify the data model): Event now holds board submissions that have no
# host and no explicit end time, and absorbs every bulletin_post via
# BulletinPostMigrator. Covers nullable host/end_time, the conditional end_time
# default, the notification gate for board submissions, and backfill parity.
class EventBoardSubmissionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def board_event(**attrs)
    Event.new({
      totem: totems(:secondary_totem),
      title: "Pottery night",
      start_time: 3.days.from_now.change(hour: 18),
      status: "active",
      provenance: "board_submission",
      approval_state: "pending_review"
    }.merge(attrs))
  end

  # ── Nullable host_user_id ────────────────────────────────────────────────

  test "board submission is valid without a host_user" do
    event = board_event
    assert_nil event.host_user_id
    assert event.valid?, event.errors.full_messages.to_sentence
    assert event.save
  end

  # ── Conditional end_time default ─────────────────────────────────────────

  test "board submission without end_time defaults to start_time + DEFAULT_DURATION" do
    event = board_event(end_time: nil)
    assert event.valid?, event.errors.full_messages.to_sentence
    assert_equal event.start_time + Event::DEFAULT_DURATION, event.end_time
  end

  test "scouted event without end_time also gets the default" do
    event = board_event(provenance: "scouted", end_time: nil)
    assert event.valid?
    assert_equal event.start_time + Event::DEFAULT_DURATION, event.end_time
  end

  test "host event still requires an explicit end_time" do
    event = board_event(provenance: "host", host_user: users(:host_user), end_time: nil)
    assert_not event.valid?
    assert_includes event.errors[:end_time], "can't be blank"
  end

  test "admin event still requires an explicit end_time" do
    event = board_event(provenance: "admin", end_time: nil)
    assert_not event.valid?
    assert_includes event.errors[:end_time], "can't be blank"
  end

  test "an explicit end_time is preserved, not overwritten" do
    explicit = 3.days.from_now.change(hour: 21)
    event = board_event(end_time: explicit)
    event.valid?
    assert_equal explicit, event.end_time
  end

  # ── Notification gate (pinned so it can't regress) ───────────────────────

  test "board_submission pending_review does not enqueue notifications" do
    assert_no_enqueued_jobs(only: [ NewEventNotificationJob, PreEventReminderJob ]) do
      board_event.save!
    end
  end

  test "even a published board_submission does not notify (only host events do)" do
    assert_no_enqueued_jobs(only: [ NewEventNotificationJob, PreEventReminderJob ]) do
      board_event(approval_state: "published").save!
    end
  end

  # ── submitter_email validation ───────────────────────────────────────────

  test "submitter_email accepts blank and a valid address, rejects garbage" do
    assert board_event(submitter_email: nil).valid?
    assert board_event(submitter_email: "me@example.com").valid?
    assert_not board_event(submitter_email: "not-an-email").valid?
  end
end
