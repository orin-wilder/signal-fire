require "test_helper"

class WeeklyDigestDeliveryJobTest < ActiveSupport::TestCase
  setup do
    @ok_result = PushNotificationService::Result.new(ok: true, error: nil)
  end

  # subscriber_user follows host_user (host_follows fixture) and host_user hosts
  # upcoming_event (1 hour from now) — qualifies for a personal digest.
  test "sends push and creates delivery for user with matching events" do
    user = users(:subscriber_user)
    user.update_column(:push_token, "ExponentPushToken[sub-token]")

    PushNotificationService.stub(:deliver, @ok_result) do
      assert_difference "NotificationDelivery.where(notification_type: 'weekly_digest').count", 1 do
        WeeklyDigestDeliveryJob.new.perform(user.id)
      end
    end
  end

  test "delivery record references the first upcoming event" do
    user = users(:subscriber_user)
    user.update_column(:push_token, "ExponentPushToken[sub-token]")

    PushNotificationService.stub(:deliver, @ok_result) do
      WeeklyDigestDeliveryJob.new.perform(user.id)
    end

    delivery = NotificationDelivery.find_by(notification_type: "weekly_digest", user: user)
    assert_not_nil delivery
    assert_equal events(:upcoming_event).id, delivery.event_id
  end

  test "skips user with no favorites or follows" do
    user = users(:regular_user)
    user.update_column(:push_token, "ExponentPushToken[regular-token]")

    delivered = false
    PushNotificationService.stub(:deliver, ->(**) { delivered = true; @ok_result }) do
      assert_no_difference "NotificationDelivery.count" do
        WeeklyDigestDeliveryJob.new.perform(user.id)
      end
    end
    assert_not delivered
  end

  test "skips user when no events are coming up (insufficient content)" do
    user = users(:follower_user)
    user.update_column(:push_token, "ExponentPushToken[follower-token]")
    # follower_user favorites main_totem but main_totem has no city_board_visible events
    # and main_totem is not city_board_visible (no character_description)

    # Move all events to the past so there's nothing in week_ahead
    Event.update_all(start_time: 2.weeks.ago, end_time: 2.weeks.ago + 1.hour)

    delivered = false
    PushNotificationService.stub(:deliver, ->(**) { delivered = true; @ok_result }) do
      WeeklyDigestDeliveryJob.new.perform(user.id)
    end
    assert_not delivered
  end

  test "push body references personal events when user has follows" do
    user = users(:subscriber_user)
    user.update_column(:push_token, "ExponentPushToken[sub-token]")

    captured_body = nil
    capture_deliver = ->(push_token:, title:, body:, data:) {
      captured_body = body
      @ok_result
    }
    PushNotificationService.stub(:deliver, capture_deliver) do
      WeeklyDigestDeliveryJob.new.perform(user.id)
    end
    assert_match "your favorite spots", captured_body
  end

  test "push data type is weekly_digest" do
    user = users(:subscriber_user)
    user.update_column(:push_token, "ExponentPushToken[sub-token]")

    captured_data = nil
    capture_deliver = ->(push_token:, title:, body:, data:) {
      captured_data = data
      @ok_result
    }
    PushNotificationService.stub(:deliver, capture_deliver) do
      WeeklyDigestDeliveryJob.new.perform(user.id)
    end
    assert_equal "weekly_digest", captured_data[:type]
  end

  # ── Idempotency ─────────────────────────────────────────────────────────────

  test "re-run in the same week does not double-push" do
    user = users(:subscriber_user)
    user.update_column(:push_token, "ExponentPushToken[sub-token]")

    pushes = 0
    PushNotificationService.stub(:deliver, ->(**) { pushes += 1; @ok_result }) do
      WeeklyDigestDeliveryJob.new.perform(user.id)
      WeeklyDigestDeliveryJob.new.perform(user.id)
    end

    assert_equal 1, pushes
    assert_equal 1, NotificationDelivery.weekly_digest.where(user: user).count
  end

  test "delivery is recorded before the push so a crashed run cannot double-send" do
    user = users(:subscriber_user)
    user.update_column(:push_token, "ExponentPushToken[sub-token]")

    PushNotificationService.stub(:deliver, ->(**) { raise Errno::ECONNRESET }) do
      assert_raises(Errno::ECONNRESET) { WeeklyDigestDeliveryJob.new.perform(user.id) }
    end

    assert NotificationDelivery.weekly_digest.exists?(
      user_id: user.id, occurrence_date: Date.current.beginning_of_week
    )
  end

  # ── Visibility gate (publicly_visible) ─────────────────────────────────────

  # The digest is a real push built from event titles — an unreviewed submission
  # must never headline it, even when it's the soonest event.
  test "pending_review events are excluded from the digest" do
    user = users(:subscriber_user)
    user.update_column(:push_token, "ExponentPushToken[sub-token]")

    totems(:main_totem).events.create!(
      title: "Unreviewed Scouted Event",
      host_user: users(:host_user),
      start_time: 30.minutes.from_now,
      end_time: 90.minutes.from_now,
      status: "active",
      provenance: "scouted",
      approval_state: "pending_review",
      source_url: "https://example.com/source"
    )

    captured_body = nil
    capture_deliver = ->(push_token:, title:, body:, data:) {
      captured_body = body
      @ok_result
    }
    PushNotificationService.stub(:deliver, capture_deliver) do
      WeeklyDigestDeliveryJob.new.perform(user.id)
    end

    assert_no_match(/Unreviewed Scouted Event/, captured_body.to_s)
    delivery = NotificationDelivery.find_by(notification_type: "weekly_digest", user: user)
    assert_equal events(:upcoming_event).id, delivery.event_id
  end
end
