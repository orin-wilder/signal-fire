class EventScoutJob < ApplicationJob
  queue_as :default

  def perform(scout_run_id)
    run = ScoutRun.find_by(id: scout_run_id)
    return unless run && (run.pending? || run.failed?)

    # A retry after a failure replaces any partial results from the first pass.
    run.candidates.destroy_all if run.failed?

    result = Ai::EventScout.call(totem: run.totem)

    if result.ok
      result.candidates.each do |c|
        run.candidates.create!(
          title:       c["title"],
          description: c["description"],
          event_date:  c["date"],
          event_time:  c["time"],
          location:    c["location"],
          source_url:  c["source_url"],
          organizer:   c["organizer"]
        )
      end
      run.update!(status: "complete")
    else
      run.update!(status: "failed", error: result.error)
    end
  rescue StandardError => e
    run&.update(status: "failed", error: e.message)
    raise
  end
end
