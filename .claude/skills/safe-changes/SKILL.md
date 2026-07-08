---
name: safe-changes
description: Use when writing migrations, touching routes or the /api/v1 API, doing backfills or bulk updates, editing seeds, or preparing any PR — every merge to main auto-deploys to production with no CI gate.
---

# Safe Changes — Production Safety Playbook

Every push to `main` deploys to production **unattended**. This skill lists the contracts that must not break and the procedures that keep you from breaking them.

## Deploy reality (verify in `render.yaml`)

- Render auto-deploys every push to `main`. There is **no CI gate** — GitHub Actions never run on this fork. Local verification is the only gate.
- `startCommand: bundle exec rails db:prepare && rails server` — **migrations run on every deploy, against prod data, with nobody watching.** (`db:seed` was removed from the startCommand 2026-07 — seeds are demo data with well-known passwords, and additionally no-op in production.)
  - `db:prepare` (not `db:migrate`) is deliberate: Solid Cache/Cable schemas load from `db/cache_schema.rb` etc., not migrations. Don't "simplify" it to `db:migrate` — the cache-backed submission throttle 500s without `solid_cache_entries`.
  - A bad migration = prod down until you fix forward. There is no staging environment.
- `healthCheckPath: /up` (Rails' built-in liveness endpoint; switched from `/about` 2026-07). `/about` must still resolve — it's a public route contract — but it is no longer the health check.

## The DO-NOT-BREAK list

1. **`/api/v1/*` routes and JSON shapes.** A frozen Expo mobile app in the field consumes them. NEVER rename routes, remove/rename JSON keys, or change key types. Additive changes only. The full per-endpoint key inventory is in [references/api-v1-contract.md](references/api-v1-contract.md) — check it before touching anything under `app/controllers/api/`.
2. **Printed-QR routes.** Physical QR codes and signage in the field point at `/t/:slug` (totem/venue board) and `/g/:code` (short code). These must resolve forever. The 301s in `config/routes.rb` (`/stpeteboards`→`/stpete`, `/board/:totem_slug`→`/t/%{totem_slug}`) must stay.
3. **The `publicly_visible` gate.** Every public read path MUST apply `Event.publicly_visible` (i.e. `approval_state = published`) so pending/unverified content never reaches a public surface. When adding any public query, thread the scope through (see `app/models/event.rb` scope + `nearby_upcoming` for the pattern).
4. **Notification fan-out gating.** `Event#enqueue_new_event_jobs` (`after_create`) only fires for `published` + `host`-provenance events; `after_update` enqueues cancellation on status flip to `cancelled`. **A backfill that creates events or flips `status` via ActiveRecord callbacks can mass-notify real users.** Check `app/models/event.rb` callbacks before any bulk write.
5. **Seeds must never reach production.** As of 2026-07 `db/seeds.rb` no-ops in production (guard at the top) and the Render startCommand no longer runs it — the seed accounts carry a shared well-known password. Keep the guard; keep seeds idempotent (`find_or_create_by!` throughout) for local use.

## Migration practice

- `db/schema.rb` is what tests load (`db:schema:load`, not migrations). Keep it exactly in sync with your migration — hand-sync if needed; a drifted schema.rb means tests pass against a DB prod won't have.
- Prefer additive migrations (add nullable column → backfill → tighten). DB-level rename precedent exists (`20260514*_rename_*`) and is fine for internal columns — but a DB rename is NOT license to rename an API JSON key: if the column feeds a serializer, keep the emitted key stable regardless (contract #1).
- Irreversible migrations are acceptable **only staged**: the bulletin retirement is the house pattern (`20260617000003_backfill_bulletin_posts_to_events` → verify parity in prod → `20260618000001_drop_bulletin_posts`). Backfill logic goes behind a service seam (e.g. `BulletinPostMigrator`) shared by the migration and a parity test. Never combine backfill + drop in one deploy.
- Run every migration locally (`bin/rails db:migrate` then `db:rollback` unless documented irreversible) before merging.

## Bulk data operations

- `update_all` / `insert_all` / `delete_all` skip validations AND callbacks. Sometimes that is exactly right (avoids the notification storm in contract #4); sometimes it corrupts data (skips slug generation, `default_end_time`). Decide consciously and say which in the PR.
- Always dry-run the scope first: `Model.where(...).count` in console, sanity-check the number, then write.

## Known gaps — do not worsen, fix when touched

(The 2026-07 trust-gate hardening PR closed the handoff-era gaps: the six ungated
`publicly_visible` read paths and the serializer 500 on host-less events — the
serializer now emits the `host` key with nullable sub-fields, per contract #1.
Tests assert each path excludes `pending_review` events; keep them green.)

- Hardcoded `signalfire.live` URLs (see Brand-coupled strings below) — owned by
  the brand-isolation PR.

## Brand-coupled strings (rebrand hazard)

Hardcoded domains exist server-side, not just in views: `share_url`/`calendar_url` in the event serializer hardcode `https://signalfire.live/...`; `Api::V1::MeController` defaults `HOST_DASHBOARD_URL` to `https://host.signalfire.live`. A domain change that misses these breaks mobile share links silently.

## Secrets / env

All secrets live in Render env vars (`RAILS_MASTER_KEY`, `DATABASE_URL`, `OPENROUTER_API_KEY`, Resend, PostHog). AI features degrade gracefully when `OPENROUTER_API_KEY` is unset — "scout does nothing" may mean a missing key, not a bug. NEVER commit a secret; there is no secret-scanning gate.

## Pre-merge checklist (run every PR)

1. `bin/rails test` fully green locally — **main's expected baseline is 0 failures** (see `dev-loop` skill). Any failure is yours until a clean-main run proves otherwise.
2. Migration run AND rolled back locally, or irreversibility documented in the PR + staged per the bulletin pattern.
3. `db/schema.rb` in sync with the migration.
4. Nothing under `app/controllers/api/` renamed/removed; JSON keys additive only (check references/api-v1-contract.md).
5. `/t/:slug`, `/g/:code`, `/about`, and the 301s still resolve.
6. Any new public event query applies `publicly_visible`.
7. Backfills audited against Event callbacks (no notification storm); bulk ops scoped and counted first.
8. `db/seeds.rb` untouched or still idempotent + prod-safe.
