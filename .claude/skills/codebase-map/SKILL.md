---
name: codebase-map
description: Use when orienting in this codebase — finding where something lives, understanding the domain model (Totem/Event/User roles), the controller namespaces, services, or routes. Load this first in any session that touches app code.
---

# Codebase Map

Rails 8.1 monolith (ERB + Tailwind + Hotwire) serving the public web app and a JSON API (`/api/v1/`) for an Expo mobile app in `mobile/`. PostgreSQL, Solid Queue (no Redis), deployed on Render.

## Vocabulary: "venue" vs `Totem` (read this first)

The product pivoted from physical QR "totems" to a citywide event calendar. **Product/UI language is "venue"; the code still says `Totem`.** The physical rename was deliberately deferred: ~200 files reference "totem", and the frozen mobile app consumes `/api/v1/totems` JSON. When writing user-facing copy, say *venue*. When writing code, follow the existing `Totem` naming. Do not start a partial rename — it happens (if ever) as one dedicated mechanical PR.

## Domain model (details: [references/data-model.md](references/data-model.md))

- **Totem** (`app/models/totem.rb`) — a venue/place. `city_slug` + unique `slug`; `short_code` for typed entry (`/g/:code`). Board-era fields (`qr_url`, `character_description`) are vestigial.
- **Event** (`app/models/event.rb`) — belongs to a totem; `host_user` optional. Three orthogonal enum state columns (plus a `created_by_admin` boolean flag — see the provenance reality check in references/data-model.md):
  - `provenance` (who created it): `host` / `admin` / `scouted` (AI-found) / `board_submission` (anonymous public). Set **server-side only**.
  - `approval_state` (moderation gate): `published` / `pending_review`. `Event.publicly_visible` scope is the single visibility gate — every public read path must apply it.
  - `status` (host lifecycle): `active` / `cancelled`.
  Recurrence via RRULE string + IceCube (`next_occurrence`). Lifecycle phase via `window_state` (±30 min check-in window).
- **User** (`app/models/user.rb`) — five-level role hierarchy (see comment at `user.rb:29`): super admin (`is_admin`) > totem admin > totem host > signed-in > anonymous. Per-totem roles live on `HostTotemAssignment.role` (`host` / `totem_admin`). Key methods: `moderated_totem_ids`, `can_moderate_totem?`, `can_auto_publish_on?`.
- **HostProfile** — one-to-one with User; invitation + magic-link token machinery; public slug (`/h/:host_slug`).
- **CheckIn** / **AnonymousCheckInCount** — day-of attendance (unique per user+event). Distinct from RSVP ("I'm going" intent), which does **not exist yet** — it's a planned Crawl-phase table (`rsvps`); check the schema before assuming either way.
- **HostFollow** / **TotemFavorite** — subscription edges with per-edge notification prefs; drive feed + notifications.
- **NotificationDelivery** — per-user/event delivery + open tracking.
- **ScoutRun** / **ScoutedEventCandidate** — AI event-scout pipeline: run → candidates → moderator promotes to a `scouted`/`pending_review` Event.
- **AnalyticsEvent** — first-party, cookieless analytics rows (`visitor_hash`), written via `AnalyticsService`.

## Controller namespaces (`app/controllers/`)

| Namespace | Audience / auth |
|---|---|
| top level + `totems/` | Public. `CitiesController#show` = `/stpete` city board; `Totems::BoardsController` = venue board; `Totems::EventSubmissionsController` = anonymous event submission; `Totems::EventPhotoExtractionsController` = photo→event prefill |
| `auth/` (+ `auth/host/`, `auth/admin/`) | Sign-up/in: email+password, magic link, Google OAuth callback |
| `host/` | Host dashboard (session auth, `require_host!`) — event CRUD, insights, profile, AI description assist |
| `totem_admin/` | Delegated per-venue moderation, scoped to `moderated_totem_ids` (`totem_admin/application_controller.rb`) |
| `admin/` | Super-admin console (`require_admin!`) — venues, hosts, events, scouts, analytics |
| `api/v1/` | Mobile JSON API. `ActionController::API` + JWT Bearer (`JwtService`); `authenticate_api_user!` / `optionally_authenticate_api_user!` (`api/v1/application_controller.rb`). JSON shape in `api/v1/concerns/event_serializer.rb` |

Web auth is session-cookie based: `current_user` / `require_user!` / `require_host!` / `require_admin!` in `app/controllers/application_controller.rb` (note: there is no `authenticate_user!` — older docs claiming so are stale).

## Services, jobs, mailers

- `app/services/`: `JwtService` (API tokens), `IcsService` (.ics export), `PushNotificationService` (Expo push), `AnalyticsService`, `OpenRouterClient` (LLM HTTP client) 
- `app/services/ai/`: `EventScout` (web-search model → candidates; **costs money per run**), `EventImageExtractor` (vision; public endpoint, throttled), `DescriptionAssistant`
- `app/services/admin/`: `InviteHostService`, `PromoteScoutedEvent` (candidate → Event)
- `app/jobs/`: `NewEventNotificationJob`, `PreEventReminderJob` (T-1h), `EventCancellationNotificationJob`, `WeeklyDigest{,Delivery}Job` (Thu 13:00 UTC via `config/recurring.yml`), `FirstStranger{Detection,Notification}Job`, `EventScoutJob`
- `app/mailers/`: `UserMailer`, `HostMailer`, `TotemMailer` — sent via Resend

## Routes that matter (`config/routes.rb`)

- `/stpete` — city board (root redirects here)
- `/t/:slug` — venue board; `/t/:slug/e/:event_slug` — event page (+ `/calendar.ics`, check-ins)
- `POST /t/:slug/events` and `/events/from_photo` — public submission funnel
- `/g/:code` — printed short-code entry; `/h/:host_slug` — host page
- **Never break:** `/t/`, `/g/` (printed QR codes in the field), and the 301s `/stpeteboards`→`/stpete`, `/board/:totem_slug`→`/t/:slug`
- `/host/*`, `/admin/*` auth scopes; nested `namespace :api` → `namespace :v1` — mobile surface (frozen client; keep JSON contract stable)

## View layer (the other half of most tasks)

Views live in `app/views/` mirroring controller paths (e.g. `CitiesController#show` → `app/views/cities/show.html.erb`; shared partials in `app/views/shared/`). Interactivity is Hotwire: Turbo frames/streams + Stimulus controllers in `app/javascript/controllers/` (e.g. `event_submission`, `event_photo`). Styling is Tailwind utility classes inline — no separate CSS files per feature. Filter-style UI is typically a GET form inside a Turbo frame.

## Project phase vocabulary

"Crawl / Walk / Run" are the pivot roadmap phases — defined in the `project-compass` skill (`references/roadmap-*.md`), not in the code. `UNIFIED_EVENT_FUNNEL_PLAN.md` at the repo root is the *previous* (completed, June 2026) plan that code comments still reference.

## Mobile app: FROZEN

`mobile/` (Expo/React Native) is deliberately frozen post-pivot: keep `/api/v1/*` routes and JSON shapes working, write no new mobile code, don't extend the API for web features.
