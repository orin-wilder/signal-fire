require "test_helper"

class Host::EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @host = users(:host_user)
    @totem = totems(:main_totem)
    @event = events(:upcoming_event)
    @co_host_event = events(:co_host_event)
    post host_login_path, params: { email: @host.email, password: "password123" }
  end

  test "GET /host/events lists own and co-host events for the totem" do
    get host_events_path
    assert_response :success
    assert_select "h1", text: /events/i
  end

  test "GET /host/events/new renders form" do
    get new_host_event_path
    assert_response :success
    assert_select "form"
  end

  test "GET /host/events/:id shows read-only view for co-host event" do
    get host_event_path(@co_host_event)
    assert_response :success
    assert_select "h1", text: /co-host event/i
  end

  test "GET /host/events/:id/edit is blocked for co-host events" do
    get edit_host_event_path(@co_host_event)
    assert_response :not_found
  end

  test "POST /host/events creates a one-time event and redirects" do
    date = 2.days.from_now.to_date
    assert_difference "Event.count", 1 do
      post host_events_path, params: {
        event: {
          title: "New Test Run",
          totem_id: @totem.id,
          recurrence_rule: "",
          start_date: date.iso8601,
          start_time_of_day: "07:00",
          end_time_of_day: "09:00",
          chat_platform: "whatsapp",
          chat_url: "https://chat.whatsapp.com/newtest123"
        }
      }
    end
    assert_redirected_to host_events_path
    assert flash[:notice].present?
  end

  test "POST /host/events creates a weekly event and redirects" do
    assert_difference "Event.count", 1 do
      post host_events_path, params: {
        event: {
          title: "Weekly Run",
          totem_id: @totem.id,
          recurrence_rule: "FREQ=WEEKLY;BYDAY=SU",
          start_day_of_week: "0",
          start_time_of_day: "07:00",
          end_time_of_day: "09:00",
          chat_platform: "whatsapp",
          chat_url: "https://chat.whatsapp.com/weeklytest456"
        }
      }
    end
    assert_redirected_to host_events_path
  end

  test "GET /host/events/:id/edit renders form for own event" do
    get edit_host_event_path(@event)
    assert_response :success
    assert_select "form"
  end

  test "PATCH /host/events/:id updates own event title" do
    patch host_event_path(@event), params: {
      event: { title: "Updated Title" }
    }
    assert_redirected_to host_events_path
    assert_equal "Updated Title", @event.reload.title
  end

  test "PATCH /host/events/:id is blocked for co-host events" do
    patch host_event_path(@co_host_event), params: {
      event: { title: "Hijacked Title" }
    }
    assert_response :not_found
    assert_not_equal "Hijacked Title", @co_host_event.reload.title
  end

  test "DELETE /host/events/:id destroys own event" do
    assert_difference "Event.count", -1 do
      delete host_event_path(@event)
    end
    assert_redirected_to host_events_path
  end

  test "DELETE /host/events/:id is blocked for co-host events" do
    assert_no_difference "Event.count" do
      delete host_event_path(@co_host_event)
    end
    assert_response :not_found
  end

  # ── Custom recurrence (INTERVAL > 2) bug fixes ──────────────────────────

  test "POST /host/events with custom WEEKLY rule uses start_date, not start_day_of_week" do
    monday = Date.new(2026, 5, 18)  # a Monday
    post host_events_path, params: {
      event: {
        title:             "Every 5 Weeks Monday Yoga",
        totem_id:          @totem.id,
        recurrence_rule:   "FREQ=WEEKLY;INTERVAL=5;BYDAY=MO",
        start_date:        monday.iso8601,
        start_day_of_week: "4",  # Thursday — should be ignored for custom rules
        start_time_of_day: "09:00",
        end_time_of_day:   "10:00",
        chat_platform:     "whatsapp",
        chat_url:          "https://chat.whatsapp.com/customweekly"
      }
    }
    event = Event.find_by!(title: "Every 5 Weeks Monday Yoga")
    assert_equal monday, event.start_time.to_date,
      "start_time must be based on start_date (Monday), not start_day_of_week (Thursday)"
  end

  test "GET /host/events/:id/edit shows custom chip active for INTERVAL=5 event" do
    event = Event.create!(
      totem:            @totem,
      host_user:        @host,
      title:            "Every 5 Weeks",
      slug:             "every-5-weeks",
      recurrence_rule:  "FREQ=WEEKLY;INTERVAL=5;BYDAY=MO",
      start_time:       1.week.from_now.change(hour: 9),
      end_time:         1.week.from_now.change(hour: 10),
      chat_platform:    "whatsapp",
      chat_url:         "https://chat.whatsapp.com/every5weeks"
    )
    get edit_host_event_path(event)
    assert_response :success
    # The "Custom" chip button must carry the active classes
    assert_select "button[data-chip-id='custom'].bg-ink", count: 1
    # The "Weekly" chip must NOT be active
    assert_select "button[data-chip-id='weekly'].bg-ink", count: 0
  end

  test "POST /host/events tracks host_event_created with correct properties" do
    date = 2.days.from_now.to_date
    tracked = []
    AnalyticsService.stub(:track, ->(name, **props) { tracked << [ name, props ] }) do
      post host_events_path, params: {
        event: {
          title: "Analytics Test Event",
          totem_id: @totem.id,
          recurrence_rule: "",
          start_date: date.iso8601,
          start_time_of_day: "09:00",
          end_time_of_day: "11:00",
          chat_platform: "whatsapp",
          chat_url: "https://chat.whatsapp.com/analyticstest"
        }
      }
    end
    assert_equal 1, tracked.size
    assert_equal "host_event_created", tracked.first[0]
    event = Event.find_by(title: "Analytics Test Event")
    assert_equal @host.id,  tracked.first[1][:host_user_id]
    assert_equal event.id,  tracked.first[1][:event_id]
    assert_equal @totem.id, tracked.first[1][:totem_id]
  end
end
