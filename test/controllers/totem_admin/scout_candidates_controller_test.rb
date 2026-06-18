require "test_helper"

# Phase 5a — promoting AI candidates, scoped to moderated totems.
class TotemAdmin::ScoutCandidatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @totem_admin = users(:totem_admin_user) # moderates main_totem
    @main        = totems(:main_totem)
    @secondary   = totems(:secondary_totem) # NOT moderated

    @run       = ScoutRun.create!(totem: @main, requested_by: @totem_admin, status: "complete")
    @candidate = @run.candidates.create!(title: "Found Jam",
                                         event_date: 5.days.from_now.to_date.iso8601, event_time: "18:00",
                                         location: "Park", source_url: "https://ex.com/a")

    @other_run       = ScoutRun.create!(totem: @secondary, requested_by: users(:admin_user), status: "complete")
    @other_candidate = @other_run.candidates.create!(title: "Off limits",
                                                     event_date: 5.days.from_now.to_date.iso8601,
                                                     source_url: "https://ex.com/b")
  end

  def sign_in(user)
    post sign_in_path, params: { email: user.email, password: "password123" }
  end

  test "add_to_totem promotes a moderated candidate to a pending scouted event" do
    sign_in(@totem_admin)
    assert_difference "Event.count", 1 do
      post add_to_totem_totem_admin_scout_candidate_path(@candidate)
    end
    event = @candidate.reload.event
    assert event, "candidate should be linked to the new event"
    assert event.provenance_scouted?
    assert event.approval_state_pending_review?
    assert_equal @main.id, event.totem_id
  end

  test "promoting a candidate never fires notifications" do
    sign_in(@totem_admin)
    assert_no_enqueued_jobs(only: [ NewEventNotificationJob, PreEventReminderJob ]) do
      post add_to_totem_totem_admin_scout_candidate_path(@candidate)
    end
  end

  test "cannot promote a candidate on a non-moderated totem" do
    sign_in(@totem_admin)
    assert_no_difference "Event.count" do
      post add_to_totem_totem_admin_scout_candidate_path(@other_candidate)
    end
    assert_response :not_found
  end

  test "ignore dismisses a moderated candidate" do
    sign_in(@totem_admin)
    post ignore_totem_admin_scout_candidate_path(@candidate)
    assert @candidate.reload.ignored?
  end

  test "cannot ignore a candidate on a non-moderated totem" do
    sign_in(@totem_admin)
    post ignore_totem_admin_scout_candidate_path(@other_candidate)
    assert_response :not_found
    assert_not @other_candidate.reload.ignored?
  end
end
