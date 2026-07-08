require "test_helper"

class EventTest < ActiveSupport::TestCase
  def build_event(overrides = {})
    Event.new({
      title: "Test Event",
      totem: Totem.new(name: "Test Totem", city_slug: "stpete"),
      host_user: users(:host_user),
      start_time: 1.hour.from_now,
      end_time: 2.hours.from_now,
      chat_url: "https://chat.whatsapp.com/abc123",
      chat_platform: :whatsapp,
      status: :active
    }.merge(overrides))
  end

  # active_now?
  test "active_now? true when current time is within window" do
    event = build_event(start_time: 20.minutes.ago, end_time: 40.minutes.from_now)
    assert event.active_now?
  end

  test "active_now? true when within before-window" do
    event = build_event(start_time: 25.minutes.from_now, end_time: 85.minutes.from_now)
    assert event.active_now?
  end

  test "active_now? true when within after-window" do
    event = build_event(start_time: 90.minutes.ago, end_time: 25.minutes.ago)
    assert event.active_now?
  end

  test "active_now? false when before window" do
    event = build_event(start_time: 2.hours.from_now, end_time: 3.hours.from_now)
    assert_not event.active_now?
  end

  test "active_now? false when after window" do
    event = build_event(start_time: 3.hours.ago, end_time: 2.hours.ago)
    assert_not event.active_now?
  end

  # Safe-by-default: publishing must be an explicit act on every create path.
  test "approval_state defaults to pending_review" do
    assert Event.new.approval_state_pending_review?
  end

  # one_time? / recurring? / weekly?
  test "one_time? true when recurrence_rule is nil" do
    assert build_event(recurrence_rule: nil).one_time?
  end

  test "recurring? true when recurrence_rule is present" do
    assert build_event(recurrence_rule: "FREQ=WEEKLY;BYDAY=MO").recurring?
  end

  test "weekly? true for simple weekly RRULE" do
    assert build_event(recurrence_rule: "FREQ=WEEKLY;BYDAY=MO").weekly?
  end

  test "weekly? false for biweekly RRULE" do
    assert_not build_event(recurrence_rule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO").weekly?
  end

  test "weekly? true when INTERVAL=1 is explicit" do
    assert build_event(recurrence_rule: "FREQ=WEEKLY;INTERVAL=1;BYDAY=MO").weekly?
  end

  test "weekly? false for double-digit intervals" do
    assert_not build_event(recurrence_rule: "FREQ=WEEKLY;INTERVAL=10;BYDAY=MO").weekly?
  end

  test "weekly? false for monthly RRULE" do
    assert_not build_event(recurrence_rule: "FREQ=MONTHLY;BYDAY=1MO").weekly?
  end

  # recurrence_rule validation
  test "valid RRULE string passes validation" do
    event = build_event(recurrence_rule: "FREQ=WEEKLY;BYDAY=SU")
    assert event.valid?
  end

  test "invalid RRULE string fails validation" do
    event = build_event(recurrence_rule: "notanrrule")
    assert_not event.valid?
    assert event.errors[:recurrence_rule].any?
  end

  test "nil recurrence_rule is valid (one-time event)" do
    event = build_event(recurrence_rule: nil)
    assert event.valid?
  end

  # The format check only vets the FREQ= prefix; the rest must actually parse.
  test "RRULE with a valid FREQ prefix but unparseable body fails validation" do
    event = build_event(recurrence_rule: "FREQ=WEEKLY;BYDAY=BANANA")
    assert_not event.valid?
    assert event.errors[:recurrence_rule].any?
  end

  test "next_occurrence falls back to start_time when a persisted rule cannot parse" do
    event = events(:weekly_event)
    event.update_column(:recurrence_rule, "FREQ=WEEKLY;BYDAY=BANANA")
    event.reload
    assert_equal event.start_time, event.next_occurrence
  end

  # next_occurrence
  test "next_occurrence returns start_time for one-time events" do
    start = 1.hour.from_now
    event = build_event(recurrence_rule: nil, start_time: start, end_time: start + 1.hour)
    assert_in_delta start.to_i, event.next_occurrence.to_i, 5
  end

  test "next_occurrence returns a future time for a weekly event with past start" do
    start = 3.weeks.ago.change(hour: 9, min: 0)
    day_abbr = %w[SU MO TU WE TH FR SA][start.wday]
    event = build_event(
      recurrence_rule: "FREQ=WEEKLY;BYDAY=#{day_abbr}",
      start_time: start,
      end_time: start + 1.hour
    )
    assert event.next_occurrence > Time.current
  end

  test "next_occurrence returns start_time for a weekly event with future start" do
    start = 1.week.from_now.change(hour: 9, min: 0)
    day_abbr = %w[SU MO TU WE TH FR SA][start.wday]
    event = build_event(
      recurrence_rule: "FREQ=WEEKLY;BYDAY=#{day_abbr}",
      start_time: start,
      end_time: start + 1.hour
    )
    assert_in_delta start.to_i, event.next_occurrence.to_i, 5
  end

  # recurrence_label
  test "recurrence_label returns nil for one-time event" do
    assert_nil build_event(recurrence_rule: nil).recurrence_label
  end

  test "recurrence_label returns a human-readable string for weekly event" do
    start = Time.current.next_occurring(:monday).change(hour: 9, min: 0)
    event = build_event(recurrence_rule: "FREQ=WEEKLY;BYDAY=MO", start_time: start, end_time: start + 1.hour)
    label = event.recurrence_label
    assert label.is_a?(String)
    assert label.present?
  end

  # validations
  test "end_time must be after start_time" do
    event = build_event(start_time: 2.hours.from_now, end_time: 1.hour.from_now)
    assert_not event.valid?
    assert event.errors[:end_time].any?
  end

  test "chat_platform is optional" do
    event = build_event(chat_platform: nil, chat_url: nil)
    assert event.valid?
  end

  test "chat_url not required when chat_platform is blank" do
    event = build_event(chat_platform: nil, chat_url: nil)
    event.valid?
    assert_not event.errors[:chat_url].any?
  end

  test "slug auto-generated from totem slug and title" do
    totem = Totem.new(name: "My Totem", city_slug: "stpete")
    totem.valid?
    event = build_event(title: "Morning Run", totem: totem)
    event.valid?
    assert_match(/my-totem-morning-run/, event.slug)
  end

  # timezone
  test "active_now? true for event happening now in Eastern time" do
    travel_to Time.zone.local(2026, 5, 4, 21, 16, 0) do
      event = build_event(
        start_time: Time.zone.local(2026, 5, 4, 21, 15, 0),
        end_time:   Time.zone.local(2026, 5, 4, 22, 15, 0)
      )
      assert event.active_now?
    end
  end

  test "active_now? false for event that ended hours ago in Eastern time" do
    travel_to Time.zone.local(2026, 5, 4, 21, 16, 0) do
      event = build_event(
        start_time: Time.zone.local(2026, 5, 4, 17, 15, 0),
        end_time:   Time.zone.local(2026, 5, 4, 19, 15, 0)
      )
      assert_not event.active_now?
    end
  end
end
