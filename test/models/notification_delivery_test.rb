require "test_helper"

class NotificationDeliveryTest < ActiveSupport::TestCase
  def build_delivery(overrides = {})
    NotificationDelivery.new({
      user: users(:regular_user),
      event: events(:upcoming_event),
      notification_type: :new_event,
      source_type: :totem_favorite
    }.merge(overrides))
  end

  test "valid notification delivery" do
    assert build_delivery.valid?
  end

  test "notification_type is required" do
    delivery = build_delivery(notification_type: nil)
    assert_not delivery.valid?
    assert delivery.errors[:notification_type].any?
  end

  test "source_type is required" do
    delivery = build_delivery(source_type: nil)
    assert_not delivery.valid?
    assert delivery.errors[:source_type].any?
  end

  test "duplicate user + event + notification_type is invalid" do
    NotificationDelivery.create!(
      user: users(:regular_user),
      event: events(:upcoming_event),
      notification_type: :new_event,
      source_type: :totem_favorite
    )
    duplicate = build_delivery
    assert_not duplicate.valid?
    assert duplicate.errors[:user_id].any?
  end

  test "same user + event with different notification_type is valid" do
    NotificationDelivery.create!(
      user: users(:regular_user),
      event: events(:upcoming_event),
      notification_type: :new_event,
      source_type: :totem_favorite
    )
    other = build_delivery(notification_type: :reminder)
    assert other.valid?
  end

  test "same user + event + type with different occurrence dates is valid" do
    NotificationDelivery.create!(
      user: users(:regular_user),
      event: events(:weekly_event),
      notification_type: :reminder,
      source_type: :totem_favorite,
      occurrence_date: Date.current
    )
    next_week = build_delivery(
      event: events(:weekly_event),
      notification_type: :reminder,
      occurrence_date: Date.current + 7
    )
    assert next_week.valid?
  end

  test "duplicate user + event + type + occurrence_date is invalid" do
    NotificationDelivery.create!(
      user: users(:regular_user),
      event: events(:weekly_event),
      notification_type: :reminder,
      source_type: :totem_favorite,
      occurrence_date: Date.current
    )
    duplicate = build_delivery(
      event: events(:weekly_event),
      notification_type: :reminder,
      occurrence_date: Date.current
    )
    assert_not duplicate.valid?
    assert duplicate.errors[:user_id].any?
  end

  test "database index blocks duplicate nil-occurrence rows even when validations are skipped" do
    attrs = {
      user_id: users(:regular_user).id,
      event_id: events(:upcoming_event).id,
      notification_type: "new_event",
      source_type: "totem_favorite",
      sent_at: Time.current
    }
    NotificationDelivery.create!(attrs)
    assert_raises(ActiveRecord::RecordNotUnique) do
      NotificationDelivery.new(attrs).save!(validate: false)
    end
  end

  test "new_event? predicate" do
    assert build_delivery(notification_type: :new_event).new_event?
  end

  test "reminder? predicate" do
    assert build_delivery(notification_type: :reminder).reminder?
  end
end
