# Crawl — the first shippable slice (planned 2026-07-02)

**Goal:** a demoable, SEO-ready citywide calendar. Small enough to actually populate
and show. No recommender, no payments, no mobile work.

**Definition of done (the demo script):** hand someone a phone → `/stpete` shows this
week grouped by day → filter to a category + weekend → tap an event → labeled detail
with venue, "I'm going," add-to-calendar → a *Found* event shows its source and a
"confirm before you go" note → Google's rich-results test passes on an event URL.

## PR sequence

### PR 0 — Trust-gate hardening (added post-plan, recommended first)

Handoff verification found the provenance system's enforcement leaking (full detail
in the `event-domain` and `safe-changes` skills). Before building new public
surfaces on top of it, fix:
- Apply `publicly_visible` to the six ungated read paths (web+API event detail,
  web+API host profiles, API home feed, `WeeklyDigestDeliveryJob`).
- Guard `event.host_user` in the API event serializer (latent 500 on host-less events).
- Get Ryan's ruling on the admin-console provenance quirk (console events carry
  `host` provenance and notify) before changing it.
Small PR, test-heavy, no migration. The whole pivot thesis is "honest labels" —
the labels have to be enforced before they're advertised.

### PR 1 — Taxonomy
- Migration: `events.category` (string, indexed, **nullable** — legacy rows stay nil
  until backfilled; do NOT backfill a default category, miscategorized is worse than nil).
- `CATEGORIES` constant (flat, ~10–12; workshop exact list with Ryan). Validation:
  inclusion + required for new records.
- Category select in every create path: host event form, public submission form,
  admin forms, AND the AI paths — `Ai::EventScout` and `Ai::EventImageExtractor`
  json_schemas get a `category` field, mapped through `Admin::PromoteScoutedEvent`
  and the photo-prefill (see `ai-pipelines` skill for where schemas live).
- One-shot backfill rake task (manual/AI-assisted) for existing events.

### PR 2 — RSVP
- Migration: `rsvps` (`user_id`, `event_id`, timestamps, unique composite index).
  No status column — un-RSVP is destroy; add columns later only if a real need appears.
- "I'm going" Turbo button on the event page + visible count ("12 going").
  Signed-out → existing magic-link flow.
- Simple "your events" list on the existing profile page.
- Deliberately distinct from check-ins (RSVP = intent, pre-event; check-in = day-of
  attendance). Keep both. No mobile API work (app frozen).
- Ships BEFORE the calendar so intent data accumulates from day one.

### PR 3 — Calendar home (flagship)
- `/stpete` becomes the day-grouped, filterable, citywide event calendar
  (replacing the venue-list city board in `CitiesController#show`).
- Filters as GET params inside Turbo frames (shareable, crawlable URLs):
  category · date preset (today / this week / this weekend / all upcoming) ·
  neighborhood (exists on the venue model) · "Verified hosts only" toggle (name the
  param `verified` to match the tier language in decisions.md — don't coin a second
  term like "confirmed" in code).
- Provenance labels go user-facing for the first time: Verified host / Community /
  Found (+ source link + "confirm before you go" on Found).
- RSVP counts as social proof on cards.
- Venue name links to `/t/:slug` — the existing board page, retitled as the venue
  page. Printed QR codes keep working untouched.
- Occurrence expansion reuses the existing narrow-in-SQL-then-Ruby pattern
  (`Event.nearby_upcoming` shape). Fine at hundreds of events; the materialized
  occurrences table is a known future fix — explicitly NOT built now.

### PR 4 — SEO layer
- schema.org/Event JSON-LD on event pages, OG/meta tags, `sitemap.xml`
  (events + venues + calendar), canonical URLs.

### PR 5 — Brand isolation (parallel; does not block on the name)
- Extract app name / logo partial / color tokens into one place so the rebrand is a
  one-PR swap. When the name lands: new domain on Render, 301 signalfire.live → new.

## Not a PR — demo seeding
Use the existing admin scout + photo-extraction tools to hand-populate a dense demo
week. Prerequisite: `OPENROUTER_API_KEY` set on Render (was unset as of June 2026 —
verify). Mind the spend: the scout uses a web-search model billed per run.

**Estimate:** ~6–8 working sessions, 2–3 weeks part-time. Each PR: local
`bin/rails test` green before merge (no CI — see `dev-loop` skill).
