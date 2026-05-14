require "test_helper"

# Wraps EventTimeAssembly so we can call its private methods directly.
class EventTimeAssemblyWrapper
  include EventTimeAssembly

  def run_assemble_times(attrs) = assemble_times(attrs)
  def run_simple_weekly?(rule)  = simple_weekly_rrule?(rule)
end

class EventTimeAssemblyTest < ActiveSupport::TestCase
  setup do
    @obj = EventTimeAssemblyWrapper.new
  end

  # ── simple_weekly_rrule? ─────────────────────────────────────────────────

  test "simple_weekly_rrule? returns true for plain FREQ=WEEKLY (no INTERVAL)" do
    assert @obj.run_simple_weekly?("FREQ=WEEKLY;BYDAY=MO")
  end

  test "simple_weekly_rrule? returns true for INTERVAL=1" do
    assert @obj.run_simple_weekly?("FREQ=WEEKLY;INTERVAL=1;BYDAY=MO")
  end

  test "simple_weekly_rrule? returns true for INTERVAL=2 (biweekly)" do
    assert @obj.run_simple_weekly?("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO")
  end

  test "simple_weekly_rrule? returns false for INTERVAL=5 (custom)" do
    assert_not @obj.run_simple_weekly?("FREQ=WEEKLY;INTERVAL=5;BYDAY=MO")
  end

  test "simple_weekly_rrule? returns false for FREQ=MONTHLY" do
    assert_not @obj.run_simple_weekly?("FREQ=MONTHLY;BYMONTHDAY=15")
  end

  test "simple_weekly_rrule? returns false for blank rule" do
    assert_not @obj.run_simple_weekly?("")
    assert_not @obj.run_simple_weekly?(nil)
  end

  # ── assemble_times with simple weekly — uses start_day_of_week ──────────

  test "assemble_times with FREQ=WEEKLY uses start_day_of_week to pick date" do
    travel_to Time.zone.local(2026, 5, 14, 12, 0, 0) do  # Thursday (wday=4)
      attrs = {
        recurrence_rule:   "FREQ=WEEKLY;BYDAY=MO",
        start_day_of_week: "1",  # Monday
        start_date:        "2026-06-01",  # ignored for simple weekly
        start_time_of_day: "09:00",
        end_time_of_day:   "10:00",
      }
      result = @obj.run_assemble_times(attrs)
      # Next Monday from Thursday 2026-05-14 is 2026-05-18
      assert_equal Date.new(2026, 5, 18), result[:start_time].to_date
    end
  end

  # ── assemble_times with custom WEEKLY — must use start_date, not wday ───

  test "assemble_times with INTERVAL=5 FREQ=WEEKLY uses start_date, not start_day_of_week" do
    travel_to Time.zone.local(2026, 5, 14, 12, 0, 0) do  # Thursday
      attrs = {
        recurrence_rule:   "FREQ=WEEKLY;INTERVAL=5;BYDAY=MO",
        start_day_of_week: "4",  # Thursday — the wrong value that caused the bug
        start_date:        "2026-05-18",  # Monday the user picked
        start_time_of_day: "09:00",
        end_time_of_day:   "10:00",
      }
      result = @obj.run_assemble_times(attrs)
      # Must be 2026-05-18 (from start_date), NOT 2026-05-14 (today/Thursday)
      assert_equal Date.new(2026, 5, 18), result[:start_time].to_date,
        "Custom WEEKLY rule must use start_date, not start_day_of_week"
    end
  end

  test "assemble_times with INTERVAL=3 FREQ=WEEKLY uses start_date" do
    travel_to Time.zone.local(2026, 5, 14, 12, 0, 0) do  # Thursday
      attrs = {
        recurrence_rule:   "FREQ=WEEKLY;INTERVAL=3;BYDAY=WE",
        start_day_of_week: "4",  # Thursday — would give wrong date if bug is present
        start_date:        "2026-05-20",  # Wednesday
        start_time_of_day: "18:00",
        end_time_of_day:   "20:00",
      }
      result = @obj.run_assemble_times(attrs)
      assert_equal Date.new(2026, 5, 20), result[:start_time].to_date,
        "INTERVAL=3 WEEKLY must use start_date"
    end
  end

  # ── assemble_times with FREQ=MONTHLY — always uses start_date ───────────

  test "assemble_times with FREQ=MONTHLY uses start_date" do
    attrs = {
      recurrence_rule:   "FREQ=MONTHLY;BYDAY=2MO",
      start_day_of_week: "4",
      start_date:        "2026-06-08",
      start_time_of_day: "10:00",
      end_time_of_day:   "11:00",
    }
    result = @obj.run_assemble_times(attrs)
    assert_equal Date.new(2026, 6, 8), result[:start_time].to_date
  end
end
