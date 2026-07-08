require "test_helper"

class TotemBoardTest < ActiveSupport::TestCase
  # board_empty?

  test "board_empty? true when totem is inactive" do
    assert totems(:inactive_totem).board_empty?
  end

  test "board_empty? false when totem has an upcoming one-time event" do
    assert_not totems(:main_totem).board_empty?
  end

  test "board_empty? false when totem has a weekly event" do
    totem = totems(:secondary_totem)
    Event.create!(
      totem: totem, host_user: users(:host_user),
      title: "Weekly Walk", recurrence_rule: "FREQ=WEEKLY;BYDAY=MO",
      start_time: 2.weeks.ago, end_time: 2.weeks.ago + 1.hour,
      chat_url: "https://chat.whatsapp.com/x", chat_platform: :whatsapp, status: :active, approval_state: :published
    )
    assert_not totem.board_empty?
  end

  test "board_empty? true when active but no upcoming or recent events" do
    totem = totems(:secondary_totem)
    assert totem.board_empty?
  end

  test "board_empty? false when totem has a recent past event (within 30 days)" do
    totem = totems(:secondary_totem)
    Event.create!(
      totem: totem, host_user: users(:host_user),
      title: "Recent Event", recurrence_rule: nil,
      start_time: 2.days.ago, end_time: 2.days.ago + 1.hour,
      chat_url: "https://chat.whatsapp.com/r", chat_platform: :whatsapp, status: :active, approval_state: :published
    )
    assert_not totem.board_empty?
  end

  # active_now_events

  test "active_now_events returns events within the check-in window" do
    totem = totems(:main_totem)
    result = totem.active_now_events
    assert_includes result.map(&:slug), events(:active_now_event).slug
  end

  test "active_now_events excludes events outside the window" do
    totem = totems(:main_totem)
    result = totem.active_now_events
    assert_not_includes result.map(&:slug), events(:upcoming_event).slug
  end

  test "active_now_events sorts: happening_now before starting_soon before just_ended" do
    totem = totems(:secondary_totem)
    just_ended  = Event.create!(totem: totem, host_user: users(:host_user), title: "A",
                    recurrence_rule: nil,
                    start_time: 90.minutes.ago, end_time: 20.minutes.ago,
                    chat_url: "https://chat.whatsapp.com/a", chat_platform: :whatsapp, status: :active, approval_state: :published)
    happening   = Event.create!(totem: totem, host_user: users(:host_user), title: "B",
                    recurrence_rule: nil,
                    start_time: 10.minutes.ago, end_time: 50.minutes.from_now,
                    chat_url: "https://chat.whatsapp.com/b", chat_platform: :whatsapp, status: :active, approval_state: :published)
    starting    = Event.create!(totem: totem, host_user: users(:host_user), title: "C",
                    recurrence_rule: nil,
                    start_time: 20.minutes.from_now, end_time: 80.minutes.from_now,
                    chat_url: "https://chat.whatsapp.com/c", chat_platform: :whatsapp, status: :active, approval_state: :published)

    result = totem.active_now_events
    assert_equal [happening.id, starting.id, just_ended.id], result.map(&:id)
  end

  # upcoming_events

  test "upcoming_events returns future events outside the active window" do
    totem = totems(:main_totem)
    result = totem.upcoming_events
    slugs = result.map(&:slug)
    assert_includes slugs, events(:upcoming_event).slug
  end

  test "upcoming_events excludes currently active events" do
    totem = totems(:main_totem)
    result = totem.upcoming_events
    assert_not_includes result.map(&:slug), events(:active_now_event).slug
  end

  test "upcoming_events includes weekly events whose next occurrence is in the future" do
    totem = totems(:main_totem)
    result = totem.upcoming_events
    assert_includes result.map(&:slug), events(:weekly_event).slug
  end
end
