module Admin
  # Turns a ScoutedEventCandidate into a real (but unpublished/pending) record on
  # the totem board (Event) and/or the bulletin board (BulletinPost). Both land in
  # a review-required state so scouted content never hits a public surface until an
  # admin publishes/approves it. Returns the (possibly invalid) record; the caller
  # checks #persisted?.
  class PromoteScoutedEvent
    DEFAULT_DURATION = 2.hours

    def self.to_totem(candidate, host_user:)
      start_time = safe_start(candidate)
      Event.create(
        totem:          candidate.scout_run.totem,
        host_user:      host_user,
        title:          candidate.title.to_s.truncate(120),
        description:    [ candidate.description, candidate.location ].compact_blank.join(" · ").presence,
        start_time:     start_time,
        end_time:       start_time + DEFAULT_DURATION,
        status:         "active",
        provenance:     "scouted",
        approval_state: "pending_review",
        source_url:     candidate.source_url,
        created_by_admin: true
      )
    end

    # Use the parsed AI date when it's in the future; otherwise a sane near-future
    # default for the pending event.
    def self.safe_start(candidate)
      parsed = candidate.starts_at
      return parsed if parsed && parsed > Time.current

      2.days.from_now.change(hour: 18, min: 0)
    end
    private_class_method :safe_start
  end
end
