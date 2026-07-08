---
name: event-domain
description: Use when touching the Event or Totem models, writing any query that returns events to users, changing visibility/moderation, recurrence (RRULE), check-ins, or event notifications. Encodes the invariants of the provenance/visibility system — the product's trust foundation.
---

# Event Domain Invariants

The Event model (`app/models/event.rb`) carries the product's trust system. Three
independent state axes — get them confused and you either leak unreviewed content
or spam users. Read this before changing anything event-shaped.

## The three state axes (orthogonal — never conflate)

| Axis | Enum | Values | Question it answers |
|---|---|---|---|
| `provenance` | prefixed (`provenance_host?`) | `host`, `admin`, `scouted`, `board_submission` | Where did this come from? |
| `approval_state` | prefixed (`approval_state_published?`) | `published`, `pending_review` | May the public see it? |
| `status` | bare (`active?`, `cancelled?`) | `active`, `cancelled` | Is it still happening? |

`provenance` and `approval_state` use `prefix: true` specifically so their
predicates don't clobber the `status` enum's bare `active?`/`cancelled?`.
**Pitfall:** `event.host?` does not exist; it's `event.provenance_host?`.
`event.cancelled?` refers to status, not moderation.

Provenance meanings: `host` = created by a verified host; `admin` = staff-entered;
`scouted` = found by the AI scout pipeline (has `source_url`); `board_submission` =
anonymous/unprivileged public submission (has `submitter_ip`/`submitter_email`,
`host_user_id` is NULL).

## Invariant 1 — provenance and approval_state are set SERVER-SIDE only

**NEVER accept `provenance`, `approval_state`, or `host_user_id` from params.**
`Totems::EventSubmissionsController#build_event` is the canonical pattern: it
assigns them explicitly after `Event.new(event_params)`, branching on
`current_user&.can_auto_publish_on?(totem)` (see `app/models/user.rb`) —
privileged users publish immediately as `host`/`admin`; everyone else becomes
`board_submission` + `pending_review` with `host_user = nil`. A submitter must
never be able to publish their own content or own an event they shouldn't.

## Invariant 2 — every public read path MUST apply the visibility gate

`Event.publicly_visible` (scope: `where(approval_state: "published")`) or the
predicate `e.publicly_visible?` **must be threaded through every query/filter
that feeds a public surface.** A new public listing that skips it is a trust bug
— it shows unreviewed anonymous submissions to the world.

Gated call sites (copy these patterns): `Totem#upcoming_events`,
`#active_now_events`, `#past_events`, `#board_empty?`, `Event.nearby_upcoming`,
`Api::V1::TotemsController#show`, `app/helpers/cities_helper.rb`, and — since the
2026-07 trust-gate hardening PR — the web/API event detail pages, web/API host
profiles, `Api::V1::HomeController`, and `WeeklyDigestDeliveryJob`. Note both forms
exist: the SQL scope (`events.active.publicly_visible`) and the Ruby predicate
(`.select { |e| e.active? && e.publicly_visible? }`) — either is fine; absence is not.

One deliberate exception: `Totems::EventsController#set_totem_and_event` bypasses
the gate for `current_user&.can_moderate_totem?(@totem)` so the admin/totem-admin
moderation queues' "View" links can preview pending events. Every other surface is
unconditionally gated; each fix carries a controller/job test asserting a
`pending_review` event is excluded — keep those green.

## Invariant 3 — notifications fan out ONLY for published host events

`Event#enqueue_new_event_jobs` (after_create) returns unless
`approval_state_published? && provenance_host?`. Scouted, admin, board-submission,
and pending events **must NEVER trigger pushes or emails** — there's no verified
human host behind them, and the product's notification budget is ~1 push per
active user per week, hard ceiling 3, never a weak push. If you add a new event
write path (import, promotion, bulk tool), preserve this gate. Publishing a
pending event via `update!(approval_state: "published")` (admin/totem_admin
publish actions) deliberately does *not* fan out — only creation does.

Console warning — **the dangerous state is the DEFAULT state**: `approval_state`
defaults to `"published"` and `provenance` to `"host"` (schema defaults), so a
bare `Event.create!(title:, totem:, host_user:, start_time:, end_time:)` with
neither field mentioned still enqueues `NewEventNotificationJob` + a scheduled
`PreEventReminderJob` for real. Cancelling (`update(status: "cancelled")`)
enqueues `EventCancellationNotificationJob` — which itself only notifies
`one_time?` events (cancelling a recurring event sends nothing; see the job's
guard). `PreEventReminderJob` self-chains weekly for `weekly?` events.

Admin console: `Admin::EventsController#create` sets `provenance: "admin"`
explicitly (plus `created_by_admin: true`), so console-created events do NOT fan
out — ruled by Ryan 2026-07-08 (previously they kept the `"host"` default and
notified; that was a bug).

## Lifecycle and check-ins

`window_state` → `:cancelled | :before | :starting_soon | :happening_now |
:just_ended | :past`. The check-in window is ±30 min around start/end
(`CHECKIN_WINDOW_BEFORE_MINUTES` / `AFTER`), enforced via `active_now?` in
`Totems::CheckInsController`. Two check-in paths: authenticated (`check_ins` rows,
unique per user+event) and anonymous (`anonymous_check_in_counts` aggregate
counter + cookie de-dupe — no per-row timestamps, so it can't be time-windowed).

## Recurrence (RRULE + IceCube)

`recurrence_rule` holds a raw RRULE string (`"FREQ=WEEKLY"`); validation only
requires it to start `FREQ=(WEEKLY|MONTHLY|DAILY|YEARLY)`. `next_occurrence`
builds an IceCube schedule per call; `one_time?` events return `start_time`
(even if past). `weekly?` intends "FREQ=WEEKLY without INTERVAL≥2" but its regex
(`/INTERVAL=[2-9]/`) only inspects one digit — `INTERVAL=10..19` is misclassified
as weekly, and it gates `PreEventReminderJob` self-chaining, so an every-10-weeks
event would get weekly reminders. Known bug (reachable: admin forms accept raw
RRULE); fix the regex when touched. Recurring events never become "past" on
boards (always a next occurrence).

**Query pattern (MUST follow):** you cannot ask SQL for "next occurrence" —
narrow candidates in SQL, then expand/sort/limit in Ruby. See
`Event.nearby_upcoming` and `Totem#upcoming_events`. This is fine at hundreds of
events; the known future fix at thousands is a materialized occurrences table —
**do not build it prematurely.** See `references/queries-and-recurrence.md`.

## end_time rules (by provenance)

`end_time` is required (model validation) for `host`/`admin` provenance; for
`scouted`/`board_submission` a `before_validation` fills
`start_time + DEFAULT_DURATION` (2h). The public quick-add form also defaults
end_time in the controller so privileged auto-publishes pass validation.
Keep `Admin::PromoteScoutedEvent::DEFAULT_DURATION` and `Event::DEFAULT_DURATION`
in sync if either changes.

## Slugs

Auto-generated on create: `"#{totem.slug}-#{title.parameterize}"` with `-2`,
`-3`… suffixes on collision. Slugs are guessable — another reason Invariant 2's
detail-page gap matters. Don't regenerate slugs on title edits (breaks shared URLs).

## Quick pitfall list

- Enum predicates: `provenance_host?`, `approval_state_published?`, but bare `active?`/`cancelled?` (status).
- `Event.active` (scope) ≠ `active_now?` (time window).
- New public query without `publicly_visible` = trust bug.
- New write path without the notification gate = spam bug.
- `belongs_to :host_user` is **optional** — always nil-safe (`event.host_user&.host_profile`).
- Timezone: submissions parse in `America/New_York` (`compose_start_time`); the app's city is St. Pete, FL.
- Totem is the venue model (product language says "venue"; code says `totem` — presentation-layer rename only, per the 2026-07 pivot).
