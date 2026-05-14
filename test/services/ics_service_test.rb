require "test_helper"

class IcsServiceTest < ActiveSupport::TestCase
  setup do
    @totem = totems(:main_totem)
    @one_time = Event.new(
      title: "One-Time Run",
      slug: "one-time-run",
      start_time: Time.utc(2026, 6, 1, 10, 0, 0),
      end_time:   Time.utc(2026, 6, 1, 11, 0, 0),
      description: "A fun run.",
      totem: @totem
    )
    @weekly = Event.new(
      title: "Weekly Swim",
      slug: "weekly-swim",
      recurrence_rule: "FREQ=WEEKLY;BYDAY=SU",
      start_time: Time.utc(2026, 6, 1, 9, 0, 0),
      end_time:   Time.utc(2026, 6, 1, 10, 0, 0),
      description: "Every Sunday.",
      totem: @totem
    )
    @monthly = Event.new(
      title: "Monthly Dance",
      slug: "monthly-dance",
      recurrence_rule: "FREQ=MONTHLY;BYDAY=1SU",
      start_time: Time.utc(2026, 6, 7, 19, 0, 0),
      end_time:   Time.utc(2026, 6, 7, 21, 0, 0),
      description: nil,
      totem: @totem
    )
  end

  test "one-time event produces valid VCALENDAR with no RRULE" do
    ics = IcsService.generate(@one_time)

    assert_includes ics, "BEGIN:VCALENDAR"
    assert_includes ics, "END:VCALENDAR"
    assert_includes ics, "BEGIN:VEVENT"
    assert_includes ics, "END:VEVENT"
    assert_includes ics, "SUMMARY:One-Time Run"
    assert_includes ics, "DTSTART:20260601T100000Z"
    assert_includes ics, "DTEND:20260601T110000Z"
    assert_includes ics, "DESCRIPTION:A fun run."
    refute_includes ics, "RRULE:"
  end

  test "weekly recurring event includes RRULE line" do
    ics = IcsService.generate(@weekly)

    assert_includes ics, "RRULE:FREQ=WEEKLY;BYDAY=SU"
  end

  test "monthly recurring event includes RRULE line" do
    ics = IcsService.generate(@monthly)

    assert_includes ics, "RRULE:FREQ=MONTHLY;BYDAY=1SU"
  end

  test "event URL uses totem and event slug" do
    ics = IcsService.generate(@one_time)

    assert_includes ics, "URL:https://signalfire.live/t/main-totem/e/one-time-run"
  end

  test "UID uses event slug" do
    ics = IcsService.generate(@one_time)

    assert_includes ics, "UID:one-time-run@signalfire.live"
  end

  test "lines are joined with CRLF" do
    ics = IcsService.generate(@one_time)

    assert_includes ics, "\r\n"
  end

  test "description with commas is escaped" do
    @one_time.description = "Bring water, snacks, and sunscreen."
    ics = IcsService.generate(@one_time)

    assert_includes ics, "DESCRIPTION:Bring water\\, snacks\\, and sunscreen."
  end

  test "nil description renders as empty DESCRIPTION field" do
    @monthly.description = nil
    ics = IcsService.generate(@monthly)

    assert_includes ics, "DESCRIPTION:"
  end
end
