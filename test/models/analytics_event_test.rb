require "test_helper"

class AnalyticsEventTest < ActiveSupport::TestCase
  test "requires a name" do
    event = AnalyticsEvent.new(occurred_at: Time.current)
    assert_not event.valid?
    assert_includes event.errors[:name], "can't be blank"
  end

  test "totem, event, and user are all optional" do
    record = AnalyticsEvent.new(name: "totem_scan", occurred_at: Time.current)
    assert record.valid?
  end

  test "since scope filters by occurred_at" do
    old = AnalyticsEvent.create!(name: "board_view", occurred_at: 10.days.ago)
    recent = AnalyticsEvent.create!(name: "board_view", occurred_at: 1.day.ago)

    results = AnalyticsEvent.since(7.days.ago)
    assert_includes results, recent
    assert_not_includes results, old
  end

  test "named scope filters by name" do
    scan = AnalyticsEvent.create!(name: "totem_scan", occurred_at: Time.current)
    view = AnalyticsEvent.create!(name: "board_view", occurred_at: Time.current)

    results = AnalyticsEvent.named("totem_scan")
    assert_includes results, scan
    assert_not_includes results, view
  end
end
