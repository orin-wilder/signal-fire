# /api/v1 JSON Contract — Frozen Mobile App

The Expo app is **frozen** (no new releases planned until post-traction). Installed copies in the field call these endpoints and parse these exact keys. **Additive changes only: never rename, remove, retype, or re-nest a key; never rename a route or change a status code.**

Source of truth is the code — re-read the controller before relying on this table. Verified 2026-07-02.

## Auth (`app/controllers/api/v1/auth/`)

`POST /api/v1/auth/sign_up`, `sign_in`, `google`, `apple`; `DELETE sign_out`. JWT via `JwtService` (`app/services/jwt_service.rb`). Bearer token in `Authorization` header. (Read the auth controllers before touching — shapes not inventoried here.)

## Shared event object — `build_event_json`

`app/controllers/api/v1/concerns/event_serializer.rb`. Used by totems#show, events#show, hosts#show.

```
id, title, slug, recurrence_rule, recurrence_label,
start_time (iso8601), end_time (iso8601), next_occurrence (iso8601),
chat_url, chat_platform, status, description, community_norms,
window_state,
host: { id, slug, name, blurb, following, host_follow_id },
share_url,      # hardcoded https://signalfire.live/t/<totem>/e/<slug>
calendar_url,   # hardcoded ...calendar.ics
user_checked_in, checked_in_at, following
```

`host_user` is optional (board_submission/scouted provenance): the serializer is nil-guarded (2026-07) and emits the `host` key with nullable sub-fields (`id`/`slug`/`name`/`blurb` may be null). Keep the key present — never remove it for host-less events.

## GET /api/v1/totems/:slug — totems#show (optional auth)

```
totem: { id, name, slug, location, sublocation, active, empty, following,
         active_now: [event...], upcoming: [event...] }
```
404: `{ error: "Not found" }`. Events filtered by `e.active? && e.publicly_visible?`.

## GET /api/v1/totems/:totem_slug/events/:event_slug — events#show (optional auth)

`{ event: <event object> }`; 404 `{ error }`. Lookup applies `publicly_visible` (2026-07) — pending events 404.

## GET /api/v1/home — home#index (auth required)

```
sections: {
  yours:   { visible } | { visible: true, items: [
             { type: "totem_favorite", totem: { id, name, slug, neighborhood,
               character_description, favorited, totem_favorite_id }, next_event },
             { type: "host_follow", host: { display_name, slug, following,
               host_follow_id }, next_event } ] },
  st_pete: { visible: true, totems: [ { id, name, slug, neighborhood,
             character_description, active_now, favorited, totem_favorite_id,
             next_event } ] },
  nearby:  { visible: false, reason: "no_adjacent_cities" }
}
next_event = { id, title, start_time (= next_occurrence iso8601), recurrence_label } | null
```
Filters `e.active? && e.publicly_visible?` (gate added 2026-07).

## GET /api/v1/hosts/:host_slug — hosts#show (optional auth)

```
host: { slug, host_user_id, display_name, host_story, following, host_follow_id,
        upcoming_events: [event...],
        totems: [ { name, slug, neighborhood } ] }
```
Filters `publicly_visible` + `status: :active` (gate added 2026-07).

## POST /api/v1/events/:event_id/check_ins — check_ins#create (auth)

201/200: `{ checked_in: true, checked_in_at (iso8601) }`. 422 `{ error: "Check-in window is not open" }` outside `active_now?` window. 404 `{ error }`.

## POST /api/v1/totems/:totem_slug/events/:event_event_slug/anonymous_check_ins (no auth)

201: `{ checked_in: true }`; 422 outside window; 404. (`ActionController::API` base — no auth stack.)

## POST /api/v1/totems/:totem_slug/email_captures (no auth)

201/200: `{ captured: true }`; 422 `{ error: "email is required" }`; sends `TotemMailer.capture_confirmation_email`.

## Host follows / totem favorites (auth)

`POST/PATCH/DELETE /api/v1/host_follows(/:id)` → `{ id, host_user_id, notify_new_event, notify_reminder }`; DELETE → 204.
`POST/PATCH/DELETE /api/v1/totem_favorites(/:id)` → `{ id, totem_id, notify_new_event, notify_reminder }`; DELETE → 204.
Create is idempotent (200 on existing, 201 on new).

## /api/v1/me — me controller (auth)

```
GET/PATCH: { id, name, email, auth_method, is_host, is_admin, push_token,
             notification_prefs,
             host_sso_url }   # only when is_host; base = ENV HOST_DASHBOARD_URL
                              # default https://host.signalfire.live (brand-coupled)
GET  /me/check_ins:     { check_ins: [ { id, checked_in_at,
                          event: { id, title, slug, start_time, totem_name, totem_slug } } ] }
GET  /me/subscriptions: { totem_favorites: [ { id, totem_id, totem_name, totem_slug,
                          notify_new_event, notify_reminder } ],
                          host_follows: [ { id, host_user_id, host_name,
                          notify_new_event, notify_reminder } ] }
POST /me/push_token:    204 | 422 { error }
DELETE /me:             204 (destroys account)
```

## When the rename happens

If/when Totem→Venue is physically renamed, these routes and keys (`totem`, `totems`, `totem_id`, `totem_name`, `totem_slug`, `totem_favorite_id`, `st_pete.totems`) must continue to be served under their current names — via aliased routes and serializer keys — until the mobile app is unfrozen and migrated (API v2 is the natural seam).
