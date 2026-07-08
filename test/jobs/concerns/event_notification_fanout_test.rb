require "test_helper"

class EventNotificationFanoutTest < ActiveSupport::TestCase
  # Use a minimal host class rather than testing through a specific job
  class FanoutHost
    include EventNotificationFanout
  end

  setup do
    @fanout = FanoutHost.new
    @event = events(:upcoming_event)
    @user = users(:subscriber_user)
    @user.update_column(:push_token, "ExponentPushToken[original]")
  end

  # --- data payload ---

  test "deliver_to sends event_slug and totem_slug in data payload" do
    captured_data = nil
    capture_deliver = ->(push_token:, title:, body:, data:) {
      captured_data = data
      PushNotificationService::Result.new(ok: true, error: nil)
    }
    PushNotificationService.stub(:deliver, capture_deliver) do
      @fanout.deliver_to(
        user: @user, event: @event, notification_type: :new_event,
        source_type: :totem_favorite, title: "T", body: "B"
      )
    end
    assert_equal @event.slug, captured_data[:event_slug]
    assert_equal @event.totem.slug, captured_data[:totem_slug]
    assert_equal @event.id, captured_data[:event_id]
  end

  # --- DeviceNotRegistered ---

  test "deliver_to clears push_token when Expo returns DeviceNotRegistered" do
    dead_result = PushNotificationService::Result.new(ok: false, error: "DeviceNotRegistered")
    PushNotificationService.stub(:deliver, dead_result) do
      @fanout.deliver_to(
        user: @user, event: @event, notification_type: :new_event,
        source_type: :totem_favorite, title: "T", body: "B"
      )
    end
    assert_nil @user.reload.push_token
  end

  test "deliver_to does not clear push_token on other Expo errors" do
    other_error = PushNotificationService::Result.new(ok: false, error: "MessageTooBig")
    PushNotificationService.stub(:deliver, other_error) do
      @fanout.deliver_to(
        user: @user, event: @event, notification_type: :new_event,
        source_type: :totem_favorite, title: "T", body: "B"
      )
    end
    assert_equal "ExponentPushToken[original]", @user.reload.push_token
  end

  test "deliver_to does not clear push_token on successful delivery" do
    ok_result = PushNotificationService::Result.new(ok: true, error: nil)
    PushNotificationService.stub(:deliver, ok_result) do
      @fanout.deliver_to(
        user: @user, event: @event, notification_type: :new_event,
        source_type: :totem_favorite, title: "T", body: "B"
      )
    end
    assert_equal "ExponentPushToken[original]", @user.reload.push_token
  end

  # --- no push token ---

  test "deliver_to does not call PushNotificationService when user has no push_token" do
    @user.update_column(:push_token, nil)
    delivered = false
    PushNotificationService.stub(:deliver, ->(**) { delivered = true }) do
      @fanout.deliver_to(
        user: @user, event: @event, notification_type: :new_event,
        source_type: :totem_favorite, title: "T", body: "B"
      )
    end
    assert_not delivered
  end

  # --- occurrence-aware dedup ---

  def deliver(occurrence_date: nil)
    @fanout.deliver_to(
      user: @user, event: @event, notification_type: :reminder,
      source_type: :host_follow, occurrence_date: occurrence_date,
      title: "T", body: "B"
    )
  end

  test "deliver_to suppresses a second send for the same occurrence" do
    ok = PushNotificationService::Result.new(ok: true, error: nil)
    PushNotificationService.stub(:deliver, ok) do
      assert_difference "NotificationDelivery.count", 1 do
        first  = deliver(occurrence_date: Date.current)
        second = deliver(occurrence_date: Date.current)
        assert_kind_of NotificationDelivery, first
        assert_nil second
      end
    end
  end

  test "deliver_to sends again for a different occurrence of the same event" do
    ok = PushNotificationService::Result.new(ok: true, error: nil)
    PushNotificationService.stub(:deliver, ok) do
      assert_difference "NotificationDelivery.count", 2 do
        deliver(occurrence_date: Date.current)
        deliver(occurrence_date: Date.current + 7)
      end
    end
  end

  test "deliver_to with nil occurrence_date stays once-ever" do
    ok = PushNotificationService::Result.new(ok: true, error: nil)
    PushNotificationService.stub(:deliver, ok) do
      assert_difference "NotificationDelivery.count", 1 do
        deliver
        deliver
      end
    end
  end

  test "deliver_to records the delivery before pushing so a retry cannot double-push" do
    PushNotificationService.stub(:deliver, ->(**) { raise Errno::ECONNRESET }) do
      assert_raises(Errno::ECONNRESET) { deliver(occurrence_date: Date.current) }
    end
    assert NotificationDelivery.exists?(
      user_id: @user.id, event_id: @event.id, notification_type: "reminder"
    )
    # the retry finds the row and skips the push
    delivered = false
    PushNotificationService.stub(:deliver, ->(**) { delivered = true }) do
      assert_nil deliver(occurrence_date: Date.current)
    end
    assert_not delivered
  end
end
