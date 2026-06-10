require "test_helper"

class Admin::ScoutCandidatesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @admin = users(:admin_user)
    @run = ScoutRun.create!(totem: totems(:main_totem), requested_by: @admin, status: "complete")
    @candidate = @run.candidates.create!(
      title: "Night market", description: "stalls + music",
      event_date: 6.days.from_now.strftime("%Y-%m-%d"), event_time: "18:00",
      location: "Downtown", source_url: "https://e.com/market", organizer: "City"
    )
  end

  def sign_in_as_admin
    post admin_login_path, params: { email: @admin.email, password: "password123" }
  end

  test "requires admin auth" do
    post add_to_totem_admin_scout_candidate_path(@candidate)
    assert_redirected_to admin_login_path
  end

  test "add_to_totem creates a pending_review scouted event, links it, and does not notify" do
    sign_in_as_admin
    assert_no_enqueued_jobs(only: NewEventNotificationJob) do
      assert_difference "Event.count", 1 do
        post add_to_totem_admin_scout_candidate_path(@candidate)
      end
    end
    event = @candidate.reload.event
    assert event.present?
    assert event.provenance_scouted?
    assert event.approval_state_pending_review?
    assert_equal "https://e.com/market", event.source_url
    # Invisible on the public board until published.
    assert_not_includes event.totem.upcoming_events, event
  end

  test "add_to_bulletin creates a pending scouted bulletin post" do
    sign_in_as_admin
    assert_difference "BulletinPost.count", 1 do
      post add_to_bulletin_admin_scout_candidate_path(@candidate)
    end
    post = @candidate.reload.bulletin_post
    assert post.present?
    assert_equal "scouted", post.source
    assert_equal "pending", post.status
  end

  test "publishing a scouted event makes it visible on the totem board" do
    sign_in_as_admin
    post add_to_totem_admin_scout_candidate_path(@candidate)
    event = @candidate.reload.event
    assert_not_includes event.totem.upcoming_events, event

    patch publish_admin_event_path(event)
    assert event.reload.approval_state_published?
    assert_includes event.totem.upcoming_events, event
  end

  test "ignore marks the candidate dismissed" do
    sign_in_as_admin
    post ignore_admin_scout_candidate_path(@candidate)
    assert @candidate.reload.ignored?
  end
end
