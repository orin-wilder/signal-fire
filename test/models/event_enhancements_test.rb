require "test_helper"

# Covers the foundation/slice additions: provenance + approval_state visibility
# gate, the notification gate, source_url + short_description validations, and
# the nearby_upcoming query.
class EventEnhancementsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def create_event(**attrs)
    defaults = {
      totem: totems(:secondary_totem),
      host_user: users(:host_user),
      title: "Test Event",
      start_time: 2.days.from_now.change(hour: 18),
      end_time: 2.days.from_now.change(hour: 20),
      status: "active",
      approval_state: "published"
    }
    Event.create!(defaults.merge(attrs))
  end

  # ── Defaults / provenance ──────────────────────────────────────────────────

  test "new events default to host / published" do
    event = create_event
    assert event.provenance_host?
    assert event.approval_state_published?
    assert event.publicly_visible?
  end

  # ── publicly_visible gate ──────────────────────────────────────────────────

  test "publicly_visible scope excludes pending_review" do
    published = create_event
    pending   = create_event(provenance: "scouted", approval_state: "pending_review")

    visible = Event.publicly_visible
    assert_includes visible, published
    assert_not_includes visible, pending
  end

  test "pending_review event is absent from Totem#upcoming_events" do
    totem     = totems(:secondary_totem)
    published = create_event(totem: totem)
    pending   = create_event(totem: totem, provenance: "scouted", approval_state: "pending_review")

    upcoming = totem.upcoming_events
    assert_includes upcoming, published
    assert_not_includes upcoming, pending
  end

  # ── Notification gate ──────────────────────────────────────────────────────

  test "published host event enqueues the new-event notification" do
    assert_enqueued_with(job: NewEventNotificationJob) do
      create_event
    end
  end

  test "scouted pending event does not enqueue notifications" do
    assert_no_enqueued_jobs(only: NewEventNotificationJob) do
      create_event(provenance: "scouted", approval_state: "pending_review")
    end
  end

  test "admin-provenance published event does not enqueue notifications" do
    assert_no_enqueued_jobs(only: NewEventNotificationJob) do
      create_event(provenance: "admin")
    end
  end

  # ── source_url validation ──────────────────────────────────────────────────

  test "source_url accepts http(s) and blank, rejects other schemes" do
    assert create_event(source_url: "https://example.com").valid?
    assert create_event(source_url: nil).valid?

    bad = Event.new(title: "x", totem: totems(:secondary_totem), host_user: users(:host_user),
                    start_time: 1.hour.from_now, end_time: 2.hours.from_now, status: "active",
                    source_url: "javascript:alert(1)")
    assert_not bad.valid?
    assert_includes bad.errors[:source_url].join, "http"
  end

  # ── short_description validation ───────────────────────────────────────────

  test "short_description must be 160 chars or fewer" do
    ok = create_event(short_description: "a" * 160)
    assert ok.valid?

    too_long = Event.new(title: "x", totem: totems(:secondary_totem), host_user: users(:host_user),
                         start_time: 1.hour.from_now, end_time: 2.hours.from_now, status: "active",
                         short_description: "a" * 161)
    assert_not too_long.valid?
  end

  # ── nearby_upcoming ────────────────────────────────────────────────────────

  test "nearby_upcoming returns other totems' published upcoming events, excluding the current totem" do
    here  = totems(:main_totem)
    there = totems(:secondary_totem)

    near    = create_event(totem: there, title: "Nearby jam")
    own     = create_event(totem: here,  title: "Own event")
    pending = create_event(totem: there, title: "Hidden", provenance: "scouted", approval_state: "pending_review")

    results = Event.nearby_upcoming(city_slug: "stpete", excluding_totem_id: here.id)

    assert_includes results, near
    assert_not_includes results, own
    assert_not_includes results, pending
  end

  test "nearby_upcoming respects the time window and limit" do
    there = totems(:secondary_totem)
    soon  = create_event(totem: there, title: "Soon", start_time: 1.day.from_now.change(hour: 18), end_time: 1.day.from_now.change(hour: 20))
    far   = create_event(totem: there, title: "Far",  start_time: 30.days.from_now.change(hour: 18), end_time: 30.days.from_now.change(hour: 20))

    results = Event.nearby_upcoming(city_slug: "stpete", excluding_totem_id: nil)
    assert_includes results, soon
    assert_not_includes results, far
  end
end
