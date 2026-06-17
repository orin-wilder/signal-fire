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

  # ── Backfill parity (BulletinPostMigrator) ───────────────────────────────

  def bulletin_post(**attrs)
    BulletinPost.create!({
      totem: totems(:secondary_totem),
      title: "Pottery night",
      description: "Bring your own clay",
      starts_at: 4.days.from_now.change(hour: 18),
      status: "approved",
      source: "public_submission",
      source_url: "https://example.com/pottery",
      submitter_ip: "203.0.113.7"
    }.merge(attrs))
  end

  test "migrator maps an approved public submission onto a published board Event" do
    post  = bulletin_post
    event = BulletinPostMigrator.build_event(post)

    assert event.save, event.errors.full_messages.to_sentence
    assert_nil   event.host_user_id
    assert_equal post.title, event.title
    assert_equal post.description, event.short_description
    assert_equal post.starts_at, event.start_time
    assert_equal post.starts_at + Event::DEFAULT_DURATION, event.end_time
    assert_equal post.source_url, event.source_url
    assert_equal post.submitter_ip, event.submitter_ip
    assert event.provenance_board_submission?
    assert event.approval_state_published?
  end

  test "migrator maps status and source to approval_state and provenance" do
    pending_admin = BulletinPostMigrator.build_event(
      bulletin_post(status: "pending", source: "admin_added")
    )
    assert pending_admin.provenance_admin?
    assert pending_admin.approval_state_pending_review?
  end

  test "migrator converts display-only recurrence into a real RRULE" do
    weekly  = BulletinPostMigrator.build_event(bulletin_post(recurring: true, recurrence_cadence: "weekly"))
    monthly = BulletinPostMigrator.build_event(bulletin_post(recurring: true, recurrence_cadence: "monthly"))
    onetime = BulletinPostMigrator.build_event(bulletin_post(recurring: false))

    assert_equal "FREQ=WEEKLY", weekly.recurrence_rule
    assert_equal "FREQ=MONTHLY", monthly.recurrence_rule
    assert_nil onetime.recurrence_rule
  end

  test "migrate_all! preserves created_at and repoints promoted scouted candidates" do
    post = bulletin_post
    run  = ScoutRun.create!(totem: totems(:secondary_totem), requested_by: users(:host_user), status: "complete")
    candidate = ScoutedEventCandidate.create!(scout_run: run, bulletin_post: post, title: "Pottery night")

    assert_no_enqueued_jobs(only: [ NewEventNotificationJob, PreEventReminderJob ]) do
      BulletinPostMigrator.migrate_all!
    end

    event = Event.find_by!(title: post.title)
    assert_equal post.created_at.to_i, event.created_at.to_i
    assert_equal event.id, candidate.reload.event_id
  end
end
