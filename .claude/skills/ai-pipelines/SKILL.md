---
name: ai-pipelines
description: Use when working on AI features — event scouting, photo-to-event extraction, description assist, OpenRouter config/models, AI cost controls and throttles, or extending the AI json_schemas (e.g., adding a field like category). Every AI call costs real money; read this before touching any of it.
---

# AI Pipelines (OpenRouter)

Three AI features, one transport. **Every call bills the OpenRouter account** — the cost invariants below are non-negotiable.

## Transport: `OpenRouterClient` (`app/services/open_router_client.rb`)

- Single wrapper for all AI calls: `OpenRouterClient.chat(model:, messages:, response_format:, plugins:, http_client:)` → `Result` (`ok`/`data`/`error` Data object). Callers own model id, prompts, and parsing; the client owns HTTP, auth, timeouts (5s open / 30s read), and error normalization.
- Auth: `ENV["OPENROUTER_API_KEY"]`. **Missing key degrades gracefully** — returns `ok: false, error: "missing OPENROUTER_API_KEY"`, never raises. If AI features "do nothing" in an environment, check this env var first (it must be set on Render for production).
- `DEFAULT_MODEL = "google/gemini-2.5-flash-lite"`. OpenRouter **retires model slugs** (an older Gemini slug already 404'd once). The constant is the single source of truth — before changing any model id, verify it exists via `https://openrouter.ai/api/v1/models`.
- Tests inject a fake `http_client` responding to `.post` — never hit the network in tests. Follow the existing test pattern.

## Feature 1: Event Scout (paid web search, moderator-gated)

Finds real upcoming events near a totem/venue via web search + structured output.

- `Ai::EventScout` (`app/services/ai/event_scout.rb`): model `google/gemini-2.5-flash:online` — the `:online` suffix enables OpenRouter web search (`plugins: [{id: "web", max_results: 5}]`), which is **the most expensive call in the app**. Strict json_schema (`SCHEMA`) returns up to 20 candidates; each must have an `http(s)` `source_url` or it's filtered out.
- Flow: controller creates `ScoutRun` (status `pending`) → `EventScoutJob` (Solid Queue) calls the scout, writes `ScoutedEventCandidate` rows, sets run `complete`/`failed` (+`error`) → moderator reviews candidates → promote or ignore. UI polls the `status` action while pending.
- **Two trigger surfaces, both authenticated** (this is the cost control):
  - `Admin::ScoutsController` — super admins, any totem.
  - `TotemAdmin::ScoutsController` / `TotemAdmin::ScoutCandidatesController` — moderators, scoped to `current_user.moderated_totem_ids` (see `User#moderated_totem_ids`, gate in `TotemAdmin::ApplicationController#require_totem_admin!`). Out-of-scope ids 404.
- Promotion: `Admin::PromoteScoutedEvent.to_totem(candidate, host_user:)` creates an Event with `provenance: "scouted"`, `approval_state: "pending_review"` (never public until a moderator publishes), `end_time = start + 2.hours`, and a safe near-future start when the AI date is unparseable/past (`ScoutedEventCandidate#starts_at` parses in America/New_York, returns nil on garbage).

## Feature 2: Photo-to-event (paid vision, PUBLIC endpoint)

`POST /t/:slug/events/from_photo` (`Totems::EventPhotoExtractionsController`) → `Ai::EventImageExtractor` (model `google/gemini-2.5-flash`, vision, non-`:online`). Base64 data-URL in, single-event JSON out to **pre-fill** the public submission form. Nothing persisted, image never touches storage; extracted data still flows through the normal create path + approval gate.

**Standing risk, know it before touching:** this is an unauthenticated endpoint that costs money per call. Its only guard is a per-IP `Rails.cache` throttle: 5 requests/hour (`THROTTLE_LIMIT`/`THROTTLE_WINDOW`), keyed `event_photo:<ip>`, **fail-open** on cache-backend errors (deliberate: an outage must not 500 the path — but it also means no cache = no throttle). The text-submission path has the same 5/hour shape, keyed separately.

## Feature 3: Description assist (host/admin-authenticated, cheap)

`Ai::DescriptionAssistant.enhance`/`.summarize(max: 160)` on `DEFAULT_MODEL`. Exposed via the `DescriptionAssistable` concern (`app/controllers/concerns/description_assistable.rb`), included by `Host::Events::DescriptionsController` (`POST /host/events/description/enhance|summarize`). JSON in/out, nothing persisted; summarize truncates defensively to the cap.

## Cost invariants (MUST / NEVER)

1. **NEVER** expose a scout trigger to unauthenticated users. Scouting is admin/moderator-gated by design — anonymous board visitors must not be able to spend money.
2. **NEVER** remove or weaken the per-IP throttles on public AI endpoints (photo extraction, submissions). If you add a new public AI endpoint, it ships with a throttle from commit one.
3. Any **scheduled/automated scouting** (planned for the Walk phase: citywide scheduled scouting) **MUST ship with an in-app spend cap / budget ledger and a kill switch**. Locked design decision — a cron that fans out `:online` calls with no budget guard is an incident, not a feature. (Today's only cap is account-level at OpenRouter, ~$20/mo per the comment in `OpenRouterClient` — verify the account setting, don't trust the comment.)
4. All AI writes land as `approval_state: "pending_review"` — AI output never reaches a public surface without human review.
5. New AI calls go **through `OpenRouterClient`** — no second HTTP path — and use strict `json_schema` `response_format` when output is parsed.

## Extending a schema (worked example: adding `category`, Crawl PR 1)

Adding a field means touching every hop end-to-end — the AI paths are only half the job:

0. **The destination column and vocabulary come first.** `events` has no `category` column and no category list exists anywhere in the codebase (grep for `categor` — nothing). So: migration for `events.category` (string, indexed, nullable for legacy rows) + a single canonical `CATEGORIES` constant on `Event` (inclusion validation). Both the AI schemas and the forms reference that one constant — never a second copy of the list.
1. `Ai::EventScout::SCHEMA` — add `category` to `properties` **and** `required` (strict mode requires all properties listed; use `type: %w[string null]` for optional-valued fields). Constrain with an `enum` built from `Event::CATEGORIES`. Update the prompt to mention it.
2. `EventScoutJob#perform` — map `c["category"]` into `run.candidates.create!` → needs a `scouted_event_candidates.category` column (second migration).
3. `Admin::PromoteScoutedEvent.to_totem` — pass it into `Event.create` (only works after step 0).
4. `Ai::EventImageExtractor::SCHEMA` + `FIELDS` — same field, nullable. The JSON flows to the submission-form prefill (`event_photo_controller.js` Stimulus) — **but a prefill value only survives if the form has the input and the controller permits it**: add the category select to `app/views/totems/event_submissions/_form.html.erb`, wire it in the Stimulus `fill()` method, and add `:category` to `event_params` in `Totems::EventSubmissionsController` (strong params silently strip unpermitted keys — precedent: `location` is in `FIELDS` today but never wired to the form, so it's extracted and then dropped).
5. Same permit-list check on every other create path (host event form, admin forms).
6. Tests: both service tests (stubbed `http_client` fixtures must include the new key — strict schema responses in fixtures need it), job test, and the promotion coverage in `test/controllers/admin/scout_candidates_controller_test.rb` + the totem_admin equivalent (there is no dedicated promote-service test file).

## Known gaps (don't assume solved)

- **No dedup exists.** Nothing prevents the same real-world event being scouted twice, or scouted *and* host-posted. Walk-phase citywide scouting needs a matching heuristic (title/date/venue) + review-queue merge before it can scale. Grep confirms: the only "dedup" in the app is notification fan-out.
- Scout is per-totem and manual-trigger only; there is no scheduler.
- Stale comment: `DescriptionAssistable` mentions the "admin bulletin-post form" — the bulletin board was retired; the concern is host-only now.
