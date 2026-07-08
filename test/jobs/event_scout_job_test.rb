require "test_helper"

class EventScoutJobTest < ActiveSupport::TestCase
  def new_run
    ScoutRun.create!(totem: totems(:main_totem), requested_by: users(:admin_user), status: "pending")
  end

  test "writes candidates and marks the run complete on success" do
    run = new_run
    candidates = [
      { "title" => "A", "description" => "d", "date" => "2026-06-20", "time" => "18:00",
        "location" => "X", "source_url" => "https://e.com/a", "organizer" => nil }
    ]
    ok = Ai::EventScout::Result.new(ok: true, candidates: candidates, error: nil)
    Ai::EventScout.stub :call, ok do
      EventScoutJob.perform_now(run.id)
    end
    run.reload
    assert run.complete?
    assert_equal 1, run.candidates.count
    assert_equal "A", run.candidates.first.title
  end

  test "marks the run failed on error" do
    run = new_run
    failure = Ai::EventScout::Result.new(ok: false, candidates: [], error: "boom")
    Ai::EventScout.stub :call, failure do
      EventScoutJob.perform_now(run.id)
    end
    run.reload
    assert run.failed?
    assert_equal "boom", run.error
  end

  # A retried job used to hit the pending?-only guard and silently no-op,
  # leaving the run failed forever.
  test "re-runs a failed run and replaces stale candidates" do
    run = new_run
    run.update!(status: "failed", error: "boom")
    run.candidates.create!(title: "Stale Partial Result")

    candidates = [
      { "title" => "Fresh", "description" => "d", "date" => "2026-06-20", "time" => "18:00",
        "location" => "X", "source_url" => "https://e.com/f", "organizer" => nil }
    ]
    ok = Ai::EventScout::Result.new(ok: true, candidates: candidates, error: nil)
    Ai::EventScout.stub :call, ok do
      EventScoutJob.perform_now(run.id)
    end

    run.reload
    assert run.complete?
    assert_equal [ "Fresh" ], run.candidates.pluck(:title)
  end

  test "does not re-run a complete run" do
    run = new_run
    run.update!(status: "complete")

    called = false
    Ai::EventScout.stub :call, ->(**) { called = true } do
      EventScoutJob.perform_now(run.id)
    end
    assert_not called
    assert run.reload.complete?
  end
end
