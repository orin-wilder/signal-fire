# Event queries, recurrence expansion, and the submission funnel — details

Companion to `event-domain/SKILL.md`. Everything here was verified against the
code on 2026-07-02; re-verify method names before relying on line-level details.

## The narrow-then-expand query pattern

RRULE recurrence lives as a string; SQL cannot compute "next occurrence".
Every upcoming/nearby listing therefore does:

1. **Narrow in SQL** — `active.publicly_visible`, join/scope by totem or city,
   `includes(...)` to avoid N+1 (`:totem`, `host_user: :host_profile`).
2. **Expand in Ruby** — call `next_occurrence` per event, then
   `select`/`sort_by`/`first(limit)`.

Canonical examples:

- `Event.nearby_upcoming(city_slug:, excluding_totem_id:, limit: 8, within: 7.days)`
  (`app/models/event.rb`) — city-wide rail, used by boards + city page.
- `Totem#upcoming_events` (`app/models/totem.rb`) — per-venue board list;
  rejects `active_now?` events, requires `next_occurrence > now + 30.min`.
- `Totem#active_now_events` — SQL time-window overlap on `start_time`/`end_time`
  directly (no recurrence expansion — happening-now only makes sense for the
  stored occurrence), with a three-tier Ruby sort: happening → starting soon →
  recently ended.
- `Totem#past_events(within: 24.hours, limit: 2)` — one-time events only
  (recurring events never go "past"); the board's short "Earlier" rail.

### Performance ceiling and the future fix

The Ruby expansion loads every candidate event for a city into memory per
request. Fine at the current scale (one city, hundreds of events). At thousands
of events (city-wide aggregation at scale), the known fix is a materialized
`event_occurrences` table (event_id, starts_at, ends_at) refreshed by a job,
so calendars become pure SQL range queries. **Do not build this until a real
page is measurably slow** — it adds a sync-consistency burden (cancel/edit/
recurrence-change must invalidate rows) that isn't worth it below that scale.

## window_state ordering (exact semantics)

```
cancelled                    (status == cancelled, checked first)
before          now <  start - 30.min
starting_soon   start - 30.min <= now <  start
happening_now   start <= now <= end
just_ended      end   <  now <= end + 30.min
past            otherwise
```

`active_now?` == `starting_soon || happening_now || just_ended` (i.e., the
±30-minute check-in window). Events without recurrence keep returning their
original `start_time` from `next_occurrence` even after it passes — callers
filter with time comparisons, don't assume next_occurrence is always future.

## Submission funnel branch (Totems::EventSubmissionsController)

`POST /t/:slug/events`, one endpoint for everyone; who you are decides the branch:

| Submitter | provenance | approval_state | host_user | extras |
|---|---|---|---|---|
| `can_auto_publish_on?(totem)` true, admin | `admin` | `published` | current_user | — |
| `can_auto_publish_on?(totem)` true, host | `host` | `published` | current_user | notifications fan out |
| anyone else (incl. signed-in non-privileged) | `board_submission` | `pending_review` | **nil** | `submitter_ip`, optional `submitter_email` |

`can_auto_publish_on?` (app/models/user.rb): admins always; `totem_admin`
assignment always; `host` assignment only with an **active** host_profile.

Spam control: per-IP fixed-window throttle via `Rails.cache`
(5 submissions/hour, `THROTTLE_LIMIT`/`THROTTLE_WINDOW`), privileged users
exempt. It **fails open** on cache errors by design — spam control must never
block a legitimate submission. Keep that property.

Form quirks: the quick-add form posts `date` + `time` strings composed via
`Time.find_zone("America/New_York").parse` (invalid → nil → validation error,
never an exception); `recurring` + `recurrence_cadence` (weekly/monthly) map to
bare `FREQ=` strings.

Review queue: `TotemAdmin::EventsController` scoped to
`current_user.moderated_totem_ids`; site admins see all via
`Admin::EventsController` (`?state=pending_review`). Publishing =
`update!(approval_state: "published")` — deliberately does NOT notify.

## Check-in paths

- **Authenticated** (`check_ins` table): unique index on (user_id, event_id);
  API: `POST /api/v1/events/:event_id/check_ins`.
- **Anonymous** (`anonymous_check_in_counts`): single aggregate row per event,
  `increment_counter`, cookie `checked_in_event_<id>` de-dupes for 24h. Web:
  `POST /t/:slug/e/:event_slug/check_ins`, rejected outside `active_now?`.
  No timestamps per check-in — cannot be windowed or attributed.

The 2026-07 pivot adds RSVP ("I'm going", pre-event intent) as a separate
concept — do not overload check-ins for it; they answer different questions
(intent vs. attendance) and the recommender learns from RSVP.

## Related jobs (app/jobs/)

- `NewEventNotificationJob` — after_create, gated (published + host only);
  recipients via the `EventNotificationFanout` concern: host-followers +
  totem-favoriters, deduped (host_follow wins attribution), filtered by the
  per-follow `notify_new_event` flag on the follow/favorite row.
- `PreEventReminderJob` — scheduled at `next_occurrence - 1.hour` on create;
  self-chains weekly for `weekly?` events (fires, then schedules next week).
  Skips silently if the event was cancelled/deleted (`return unless event&.active?`).
  Filtered by per-follow `notify_reminder`; **for recurring events, reminders go
  only to prior attendees** (users with a check-in at the same totem+host) — a
  deliberate notification-discipline mechanism; preserve it.
- `EventCancellationNotificationJob` — on status → cancelled.
- `FirstStrangerDetectionJob` / `FirstStrangerNotificationJob` — host delight
  ("someone new checked in"), uses `user_host_first_seens`.
- `WeeklyDigestJob`/`WeeklyDigestDeliveryJob` — Thursday 13:00 UTC via
  `config/recurring.yml`.
