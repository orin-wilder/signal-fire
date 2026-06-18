require "test_helper"

# Phase 3 — the unified submission funnel. Who submits decides whether the event
# publishes immediately (totem host / totem admin / super admin) or lands in the
# review queue (anonymous / signed-in non-privileged).
class Totems::EventSubmissionsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @totem = totems(:main_totem) # host_user + totem_admin_user moderate this
  end

  def valid_params(overrides = {})
    { event: {
        title: "Pickup Soccer",
        date: 3.days.from_now.to_date.iso8601,
        time: "18:00",
        short_description: "Bring water",
        source_url: "https://example.com/soccer"
      }.merge(overrides) }
  end

  def latest_event = Event.order(:created_at, :id).last

  def sign_in(user)
    post sign_in_path, params: { email: user.email, password: "password123" }
  end

  # ── Anonymous ──────────────────────────────────────────────────────────────

  test "anonymous submission creates a pending board_submission with ip and no host" do
    assert_difference "Event.count", 1 do
      post totem_event_submissions_path(@totem.slug), params: valid_params
    end
    e = latest_event
    assert e.provenance_board_submission?
    assert e.approval_state_pending_review?
    assert_nil e.host_user_id
    assert e.submitter_ip.present?
    assert e.end_time.present?, "end_time should default for board submissions"
    assert_redirected_to totem_board_path(@totem.slug)
  end

  test "anonymous submission does not enqueue notifications" do
    assert_no_enqueued_jobs(only: [ NewEventNotificationJob, PreEventReminderJob ]) do
      post totem_event_submissions_path(@totem.slug), params: valid_params
    end
  end

  test "anonymous submission records submitter_email when provided" do
    post totem_event_submissions_path(@totem.slug), params: valid_params(submitter_email: "me@example.com")
    assert_equal "me@example.com", latest_event.submitter_email
  end

  # ── Signed-in non-privileged ────────────────────────────────────────────────

  test "signed-in plain user stays pending with nil host_user" do
    sign_in(users(:regular_user))
    post totem_event_submissions_path(@totem.slug), params: valid_params
    e = latest_event
    assert e.provenance_board_submission?
    assert e.approval_state_pending_review?
    assert_nil e.host_user_id
  end

  # ── Totem host (auto-publish) ───────────────────────────────────────────────

  test "totem host auto-publishes as host, owning the event" do
    sign_in(users(:host_user))
    post totem_event_submissions_path(@totem.slug), params: valid_params
    e = latest_event
    assert e.provenance_host?
    assert e.approval_state_published?
    assert_equal users(:host_user).id, e.host_user_id
  end

  test "totem host auto-publish fires the new-event notification" do
    sign_in(users(:host_user))
    assert_enqueued_with(job: NewEventNotificationJob) do
      post totem_event_submissions_path(@totem.slug), params: valid_params
    end
  end

  # ── Totem admin (auto-publish) ──────────────────────────────────────────────

  test "totem admin auto-publishes" do
    sign_in(users(:totem_admin_user))
    post totem_event_submissions_path(@totem.slug), params: valid_params
    e = latest_event
    assert e.approval_state_published?
    assert e.provenance_host?, "non-super-admin auto-publisher records :host provenance"
    assert_equal users(:totem_admin_user).id, e.host_user_id
  end

  # ── Super admin (auto-publish as admin) ─────────────────────────────────────

  test "super admin auto-publishes with admin provenance and no notification" do
    sign_in(users(:admin_user))
    assert_no_enqueued_jobs(only: [ NewEventNotificationJob, PreEventReminderJob ]) do
      post totem_event_submissions_path(@totem.slug), params: valid_params
    end
    e = latest_event
    assert e.provenance_admin?
    assert e.approval_state_published?
    assert_equal users(:admin_user).id, e.host_user_id
  end

  # ── Recurrence + validation + 404 ───────────────────────────────────────────

  test "recurring weekly submission becomes a real RRULE" do
    post totem_event_submissions_path(@totem.slug),
         params: valid_params(recurring: "1", recurrence_cadence: "weekly")
    assert_equal "FREQ=WEEKLY", latest_event.recurrence_rule
  end

  test "invalid submission re-renders the form via turbo_stream" do
    assert_no_difference "Event.count" do
      post totem_event_submissions_path(@totem.slug), params: valid_params(title: ""), as: :turbo_stream
    end
    assert_response :unprocessable_entity
    assert_match "event-submission-form", response.body
  end

  test "unknown totem slug returns 404" do
    post totem_event_submissions_path("no-such-totem"), params: valid_params
    assert_response :not_found
  end

  # ── Throttle (cache-backed; swap the null_store for a real one) ──────────────

  test "anonymous submissions are throttled per IP" do
    store = ActiveSupport::Cache::MemoryStore.new
    Rails.stub(:cache, store) do
      Totems::EventSubmissionsController::THROTTLE_LIMIT.times do
        post totem_event_submissions_path(@totem.slug), params: valid_params
      end
      assert_no_difference "Event.count" do
        post totem_event_submissions_path(@totem.slug), params: valid_params
      end
      assert_redirected_to totem_board_path(@totem.slug)
    end
  end

  test "auto-publishers are exempt from the throttle" do
    store = ActiveSupport::Cache::MemoryStore.new
    Rails.stub(:cache, store) do
      sign_in(users(:host_user))
      assert_difference "Event.count", Totems::EventSubmissionsController::THROTTLE_LIMIT + 1 do
        (Totems::EventSubmissionsController::THROTTLE_LIMIT + 1).times do
          post totem_event_submissions_path(@totem.slug), params: valid_params
        end
      end
    end
  end
end
