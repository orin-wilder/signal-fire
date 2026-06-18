require "test_helper"

# Phase 3 — delegated moderation queue. A totem admin moderates only their
# assigned totems and can never touch events on totems they don't moderate.
class TotemAdmin::EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @totem_admin = users(:totem_admin_user) # moderates main_totem only
    @main        = totems(:main_totem)
    @secondary   = totems(:secondary_totem) # NOT moderated by @totem_admin

    @pending_main      = create_pending(@main, "Pending on main")
    @pending_secondary = create_pending(@secondary, "Pending on secondary")
  end

  def create_pending(totem, title)
    Event.create!(totem: totem, title: title, status: "active",
                  provenance: "board_submission", approval_state: "pending_review",
                  start_time: 2.days.from_now.change(hour: 18, min: 0))
  end

  def sign_in(user)
    post sign_in_path, params: { email: user.email, password: "password123" }
  end

  test "redirects when not a totem admin" do
    get totem_admin_events_path
    assert_redirected_to sign_in_path
  end

  test "index shows only pending events on moderated totems" do
    sign_in(@totem_admin)
    get totem_admin_events_path
    assert_response :success
    assert_match "Pending on main", response.body
    assert_no_match(/Pending on secondary/, response.body)
  end

  test "publish flips pending to published on a moderated totem" do
    sign_in(@totem_admin)
    patch publish_totem_admin_event_path(@pending_main)
    assert @pending_main.reload.approval_state_published?
    assert_redirected_to totem_admin_events_path
  end

  test "cannot publish an event on a non-moderated totem" do
    sign_in(@totem_admin)
    patch publish_totem_admin_event_path(@pending_secondary)
    assert_response :not_found
    assert @pending_secondary.reload.approval_state_pending_review?
  end

  test "cannot edit an event on a non-moderated totem" do
    sign_in(@totem_admin)
    get edit_totem_admin_event_path(@pending_secondary)
    assert_response :not_found
  end

  test "cannot destroy an event on a non-moderated totem" do
    sign_in(@totem_admin)
    delete totem_admin_event_path(@pending_secondary)
    assert_response :not_found
    assert Event.exists?(@pending_secondary.id)
  end

  test "update edits a moderated event and preserves recurrence" do
    sign_in(@totem_admin)
    @pending_main.update!(recurrence_rule: "FREQ=WEEKLY")
    patch totem_admin_event_path(@pending_main), params: { event: {
      title: "Edited title", recurrence_rule: "FREQ=WEEKLY",
      start_date: 3.days.from_now.to_date.iso8601, start_time_of_day: "19:00", end_time_of_day: "21:00"
    } }
    assert_redirected_to totem_admin_events_path
    @pending_main.reload
    assert_equal "Edited title", @pending_main.title
    assert_equal "FREQ=WEEKLY", @pending_main.recurrence_rule
  end

  test "super admin moderates any totem" do
    sign_in(users(:admin_user))
    patch publish_totem_admin_event_path(@pending_secondary)
    assert @pending_secondary.reload.approval_state_published?
  end
end
