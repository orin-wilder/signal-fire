# Phase 2 backfill seam: maps a legacy bulletin post onto an Event. Historical —
# the backfill already ran in every real environment; this only executes on a
# fresh `db:migrate` replay (where bulletin_posts still exists before the later
# drop migration). Reads the table directly so it survives deletion of the
# BulletinPost model.
class BulletinPostMigrator
  # Decoupled reader for the legacy bulletin_posts table (no app model needed).
  class Source < ActiveRecord::Base
    self.table_name = "bulletin_posts"
  end

  # bulletin_posts.source -> events.provenance
  PROVENANCE_BY_SOURCE = {
    "public_submission" => "board_submission",
    "scouted"           => "scouted",
    "admin_added"       => "admin"
  }.freeze

  # Display-only recurring/cadence -> a real RRULE so it flows through IceCube
  # like any other recurring event (a deliberate behavior upgrade).
  RRULE_BY_CADENCE = {
    "weekly"  => "FREQ=WEEKLY",
    "monthly" => "FREQ=MONTHLY"
  }.freeze

  def self.event_attributes(post)
    start_time = post.starts_at
    {
      totem_id:          post.totem_id,
      host_user_id:      nil,
      title:             post.title,
      short_description: post.description&.truncate(160),
      start_time:        start_time,
      end_time:          (start_time + Event::DEFAULT_DURATION if start_time),
      status:            "active",
      provenance:        PROVENANCE_BY_SOURCE.fetch(post.source, "board_submission"),
      approval_state:    (post.status == "approved" ? "published" : "pending_review"),
      source_url:        post.source_url.presence,
      recurrence_rule:   rrule_for(post),
      submitter_ip:      post.submitter_ip
    }
  end

  def self.rrule_for(post)
    return nil unless post.recurring?

    RRULE_BY_CADENCE[post.recurrence_cadence]
  end

  def self.build_event(post)
    Event.new(event_attributes(post))
  end

  # One-time backfill. Saves an Event per post (slug autogenerates), preserves
  # the original timestamps, and repoints any scouted candidate that had promoted
  # to this post onto the new Event. The notification gate never fires here — no
  # backfilled row is host-authored.
  def self.migrate_all!
    Source.find_each do |post|
      event = build_event(post)
      event.save!
      event.update_columns(created_at: post.created_at, updated_at: post.updated_at)

      ScoutedEventCandidate.where(bulletin_post_id: post.id)
                           .update_all(event_id: event.id)
    end
  end
end
