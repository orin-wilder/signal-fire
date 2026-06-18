require "test_helper"

class Admin::EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin    = users(:admin_user)
    @host     = users(:host_user)
    @totem    = totems(:main_totem)
    @event    = events(:upcoming_event)
    @past     = events(:past_event)
    @cancelled = events(:cancelled_event)
  end

  # ── Auth guard ────────────────────────────────────────────────────────────

  test "GET /admin/events redirects to login when not signed in" do
    get admin_events_path
    assert_redirected_to admin_login_path
  end

  # ── Index ─────────────────────────────────────────────────────────────────

  test "GET /admin/events lists all events" do
    sign_in_as_admin
    get admin_events_path
    assert_response :success
    assert_select "h1", text: /events/i
    assert_select "td", text: @event.title
  end

  test "GET /admin/events filters by title" do
    sign_in_as_admin
    get admin_events_path, params: { q: @event.title }
    assert_response :success
    assert_select "td", text: @event.title
    assert_select "td", text: @cancelled.title, count: 0
  end

  test "GET /admin/events?state=pending_review shows only the review queue" do
    sign_in_as_admin
    pending = Event.create!(totem: @totem, title: "Needs review", status: "active",
                            provenance: "board_submission", approval_state: "pending_review",
                            start_time: 2.days.from_now.change(hour: 18, min: 0))
    get admin_events_path, params: { state: "pending_review" }
    assert_response :success
    assert_select "td", text: pending.title
    assert_select "td", text: @event.title, count: 0
  end

  test "GET /admin/events filters by totem name" do
    sign_in_as_admin
    get admin_events_path, params: { q: @totem.name }
    assert_response :success
    assert_select "td", text: @event.title
  end

  test "GET /admin/events shows empty state when no results match" do
    sign_in_as_admin
    get admin_events_path, params: { q: "zzznomatch" }
    assert_response :success
    assert_select "p", text: /no events match/i
  end

  test "GET /admin/events shows Created by admin label for admin-created events" do
    sign_in_as_admin
    @event.update!(created_by_admin: true)
    get admin_events_path
    assert_select "p", text: /created by admin/i
  end

  # ── New / Create ──────────────────────────────────────────────────────────

  test "GET /admin/events/new renders form with host selector" do
    sign_in_as_admin
    get new_admin_event_path
    assert_response :success
    assert_select "form"
    assert_select "select[name='event[host_user_id]']"
  end

  test "POST /admin/events creates event on behalf of host with created_by_admin=true" do
    sign_in_as_admin
    date = 3.days.from_now.to_date
    assert_difference "Event.count", 1 do
      post admin_events_path, params: {
        event: {
          host_user_id: @host.id,
          title: "Admin Created Event",
          totem_id: @totem.id,
          recurrence_rule: "",
          start_date: date.iso8601,
          start_time_of_day: "10:00",
          end_time_of_day: "11:00",
          chat_platform: "whatsapp",
          chat_url: "https://chat.whatsapp.com/admintest999"
        }
      }
    end
    assert_redirected_to admin_events_path
    created = Event.last
    assert_equal @host, created.host_user
    assert created.created_by_admin
    assert_equal "Admin Created Event", created.title
  end

  test "POST /admin/events creates weekly event and redirects" do
    sign_in_as_admin
    assert_difference "Event.count", 1 do
      post admin_events_path, params: {
        event: {
          host_user_id: @host.id,
          title: "Weekly Admin Event",
          totem_id: @totem.id,
          recurrence_rule: "FREQ=WEEKLY;BYDAY=WE",
          start_day_of_week: "3",
          start_time_of_day: "08:00",
          end_time_of_day: "09:00",
          chat_platform: "discord",
          chat_url: "https://discord.gg/adminweekly"
        }
      }
    end
    assert_redirected_to admin_events_path
    assert Event.last.weekly?
  end

  # ── Edit / Update ─────────────────────────────────────────────────────────

  test "GET /admin/events/:id/edit renders form" do
    sign_in_as_admin
    get edit_admin_event_path(@event)
    assert_response :success
    assert_select "form"
    assert_select "select[name='event[host_user_id]']"
  end

  test "PATCH /admin/events/:id updates title and redirects" do
    sign_in_as_admin
    patch admin_event_path(@event), params: {
      event: {
        host_user_id: @host.id,
        title: "Updated Title",
        totem_id: @totem.id,
        recurrence_type: "one_time",
        start_date: @event.start_time.to_date.iso8601,
        start_time_of_day: @event.start_time.strftime("%H:%M"),
        end_time_of_day: @event.end_time.strftime("%H:%M"),
        chat_platform: @event.chat_platform,
        chat_url: @event.chat_url
      }
    }
    assert_redirected_to admin_events_path
    assert_equal "Updated Title", @event.reload.title
  end

  test "PATCH /admin/events/:id can reassign host" do
    sign_in_as_admin
    co_host = users(:co_host_user)
    patch admin_event_path(@event), params: {
      event: {
        host_user_id: co_host.id,
        title: @event.title,
        totem_id: @totem.id,
        recurrence_type: "one_time",
        start_date: @event.start_time.to_date.iso8601,
        start_time_of_day: @event.start_time.strftime("%H:%M"),
        end_time_of_day: @event.end_time.strftime("%H:%M"),
        chat_platform: @event.chat_platform,
        chat_url: @event.chat_url
      }
    }
    assert_redirected_to admin_events_path
    assert_equal co_host, @event.reload.host_user
  end

  # ── Destroy ───────────────────────────────────────────────────────────────

  test "DELETE /admin/events/:id destroys event and redirects" do
    sign_in_as_admin
    assert_difference "Event.count", -1 do
      delete admin_event_path(@event)
    end
    assert_redirected_to admin_events_path
  end

  test "DELETE /admin/events/:id can delete cancelled event" do
    sign_in_as_admin
    assert_difference "Event.count", -1 do
      delete admin_event_path(@cancelled)
    end
    assert_redirected_to admin_events_path
  end

  private

  def sign_in_as_admin
    post admin_login_path, params: { email: @admin.email, password: "password123" }
  end
end
