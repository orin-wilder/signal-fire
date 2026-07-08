# Data model reference

Verified against `db/schema.rb` (version 2026_06_22_000003). Re-check the schema before relying on column lists — this file is a snapshot.

## Entity relationships

```
Totem 1—* Event *—1 User(host_user, optional)
Totem 1—* HostTotemAssignment *—1 User          (role: host | totem_admin)
Totem 1—* TotemFavorite *—1 User                 (notify_new_event, notify_reminder)
User  1—1 HostProfile
User  1—* HostFollow *—1 User(host_user)         (notify_new_event, notify_reminder)
Event 1—* CheckIn *—1 User                       (unique user+event)
Event 1—1 AnonymousCheckInCount
Event 1—* NotificationDelivery *—1 User
Totem 1—* ScoutRun 1—* ScoutedEventCandidate —?1 Event (after promotion)
Totem 1—* EmptyTotemEmailCapture
User  *—* User via UserHostFirstSeen             (first-stranger detection)
```

## events — the state columns (do not conflate)

| Column | Values | Meaning | Who changes it |
|---|---|---|---|
| `provenance` | `host`, `admin`, `scouted`, `board_submission` | Origin/trust tier. Immutable in practice; set server-side at creation (never from params) | Controllers/services only |
| `approval_state` | `published`, `pending_review` | Moderation gate. `Event.publicly_visible` = `where(approval_state: "published")` — **the** public visibility gate | Moderators (publish actions) |
| `status` | `active`, `cancelled` | Host lifecycle. Cancelling enqueues `EventCancellationNotificationJob` | Host/admin cancel actions |
| `created_by_admin` | boolean | A fourth, easy-to-miss flag set by the admin console and host controllers; read in the admin events index | `Admin::EventsController`, `Host::EventsController`, `PromoteScoutedEvent` |

Enum gotcha: `provenance` and `approval_state` are declared with `prefix: true` (`event.provenance_host?`, `event.approval_state_published?`); `status` is unprefixed (`event.active?`, `event.cancelled?`). See `app/models/event.rb`.

**Provenance reality check (surprising, verified):** `provenance: "admin"` is only produced when a *super-admin uses the public totem-board submission form* (`Totems::EventSubmissionsController`). The admin console's own new-event form (`Admin::EventsController#create`) never sets provenance, so console-created events keep the schema default `"host"` — meaning they pass the notification gate below and DO fan out pushes if published with a `host_user`. If you expected `provenance_admin?` from the admin console, you'll be wrong; `created_by_admin` is the flag that path actually sets. Flagged to Ryan during handoff as a possible latent inconsistency — don't "fix" it silently, it may be intentional.

Other notable `events` columns: `recurrence_rule` (RRULE string, validated `FREQ=...`), `end_time` (required only for host/admin provenance; others default to `start_time + Event::DEFAULT_DURATION` = 2h), `source_url` (scouted origin link), `submitter_email`/`submitter_ip` (anonymous board submissions), `chat_platform`/`chat_url`, `short_description` (≤160 chars), unique `slug` (auto: `{totem-slug}-{title}`, numeric suffixes on collision).

Notification gating (in `Event#enqueue_new_event_jobs`): only `published` + `host`-provenance events fan out pushes/reminders. Scouted/board-submission/(true-)admin-provenance events never notify — but see the provenance reality check above: admin-*console* events carry `host` provenance and do notify. Preserve this invariant when touching callbacks or backfills.

## users

- Auth: `auth_method` enum (`email`/`google`/`apple`), `password_digest` (bcrypt, validations off — magic-link/OAuth users have none), `magic_link_token` (+expiry, 30 min), `google_uid`.
- Roles: `is_admin` (super admin), `is_host` (flag; real gate is `host_profile.active?`), per-totem `HostTotemAssignment.role`.
- `notification_prefs` jsonb: `{"all", "reminder", "new_event"}` booleans.
- `push_token` — Expo push token (mobile).

## host_profiles

Invitation lifecycle: `invite_status` (default `"invited"`), `invitation_token` (+expiry), `invite_accepted_at`, plus a host-specific `magic_link_token`. Public `slug`. `display_name`, `blurb`, `host_story`, `timezone`. Host onboarding is invite-only today (`Admin::InviteHostService`); self-serve signup is a planned Walk-phase change.

## totems (venues)

`name`, `location` (required), `sublocation`, `neighborhood` (**freeform text, no canonical list** — a filter dropdown needs `Totem.distinct.pluck(:neighborhood)` or a curated list), `city_slug` (default `"stpete"`), unique `slug`, `active` (default **false** — new venues are invisible until activated), `short_code` (unique numeric string, ≥2 digits, auto-generated), vestigial `qr_url` / `character_description` (≤140).

Scopes: `active`, `for_city(slug)`, `city_board_visible` (= active AND has `character_description` — a board-era constraint; the calendar-home rebuild should not depend on it).

## Not in the schema (as of this writing)

- **No `rsvps` table** — RSVP/"I'm going" is planned (Crawl PR 2). Check `db/schema.rb` first.
- **No `category` column on events** — taxonomy is planned (Crawl PR 1).
- No payments/orders/subscriptions tables — deliberately deferred to the Run phase.

## Analytics

`analytics_events`: name + `occurred_at` + optional `user_id`/`totem_id`/`event_id`/`source`/`visitor_hash` (cookieless). Written through `AnalyticsService.track`; viewed at `/admin/analytics`. PostHog also runs client-side (web + mobile).
