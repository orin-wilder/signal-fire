require "test_helper"

# Phase 5a — delegated AI event discovery. A moderator can scout only the totems
# they moderate.
class TotemAdmin::ScoutsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @totem_admin = users(:totem_admin_user) # moderates main_totem
    @main        = totems(:main_totem)
    @secondary   = totems(:secondary_totem) # NOT moderated
  end

  def sign_in(user)
    post sign_in_path, params: { email: user.email, password: "password123" }
  end

  test "requires totem admin" do
    get new_totem_admin_scout_path
    assert_redirected_to sign_in_path
  end

  test "new lists only moderated totems" do
    sign_in(@totem_admin)
    get new_totem_admin_scout_path
    assert_response :success
    assert_match @main.name, response.body
    assert_no_match(/#{@secondary.name}/, response.body)
  end

  test "create scouts a moderated totem and enqueues the job" do
    sign_in(@totem_admin)
    assert_difference "ScoutRun.count", 1 do
      assert_enqueued_with(job: EventScoutJob) do
        post totem_admin_scouts_path, params: { totem_id: @main.id }
      end
    end
    run = ScoutRun.order(:created_at).last
    assert_equal @main.id, run.totem_id
    assert_equal @totem_admin.id, run.requested_by_id
    assert_redirected_to totem_admin_scout_path(run)
  end

  test "cannot scout a non-moderated totem" do
    sign_in(@totem_admin)
    assert_no_difference "ScoutRun.count" do
      post totem_admin_scouts_path, params: { totem_id: @secondary.id }
    end
    assert_response :not_found
  end

  test "cannot view a run on a non-moderated totem" do
    sign_in(@totem_admin)
    other = ScoutRun.create!(totem: @secondary, requested_by: users(:admin_user), status: "complete")
    get totem_admin_scout_path(other)
    assert_response :not_found
  end

  test "shows a completed run with its candidates" do
    sign_in(@totem_admin)
    run = ScoutRun.create!(totem: @main, requested_by: @totem_admin, status: "complete")
    run.candidates.create!(title: "Found Jam", event_date: "2026-07-01", source_url: "https://ex.com/a")
    get totem_admin_scout_path(run)
    assert_response :success
    assert_match "Found Jam", response.body
  end

  test "super admin can scout any totem" do
    sign_in(users(:admin_user))
    assert_difference "ScoutRun.count", 1 do
      post totem_admin_scouts_path, params: { totem_id: @secondary.id }
    end
  end
end
