require "test_helper"

class Admin::ScoutsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @admin = users(:admin_user)
    @totem = totems(:main_totem)
  end

  def sign_in_as_admin
    post admin_login_path, params: { email: @admin.email, password: "password123" }
  end

  test "requires admin auth" do
    get new_admin_scout_path
    assert_redirected_to admin_login_path
  end

  test "new renders a totem picker" do
    sign_in_as_admin
    get new_admin_scout_path
    assert_response :success
    assert_select "select[name=totem_id]"
  end

  test "create starts a run and enqueues the scout job" do
    sign_in_as_admin
    assert_enqueued_with(job: EventScoutJob) do
      assert_difference "ScoutRun.count", 1 do
        post admin_scouts_path, params: { totem_id: @totem.id }
      end
    end
    run = ScoutRun.last
    assert_equal "pending", run.status
    assert_equal @admin, run.requested_by
    assert_redirected_to admin_scout_path(run)
  end

  test "show renders the review queue when complete" do
    sign_in_as_admin
    run = ScoutRun.create!(totem: @totem, requested_by: @admin, status: "complete")
    run.candidates.create!(title: "Found event", source_url: "https://e.com/x", event_date: "2026-06-20")
    get admin_scout_path(run)
    assert_response :success
    assert_select "td", text: /Found event/
  end

  test "status returns JSON for polling" do
    sign_in_as_admin
    run = ScoutRun.create!(totem: @totem, requested_by: @admin, status: "pending")
    get status_admin_scout_path(run)
    assert_response :success
    assert_equal "pending", response.parsed_body["status"]
  end
end
