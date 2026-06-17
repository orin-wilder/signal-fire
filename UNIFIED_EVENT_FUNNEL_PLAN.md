# Signal Fire — Unified Community Event Funnel + Role Hierarchy + Physical Totem Short-Code

> **Status:** Design plan headed to Ultraplan for cloud refinement — **not yet greenlit for implementation.** Captures the totem-redesign discussion of 2026-06-17 (physical totem durability/art, the unified event funnel, the 5-role hierarchy, AI friction-reducers, and the short-code URL fallback).

## Context

The scrappy field test (paint-stick QR totems → bulletin board) validated the *concept* — bystanders understood a "community bulletin board" faster from the physical object than from explanation — but exposed two problems: a top-of-funnel trust/legibility gap ("why would I scan this?") and a bottom-of-funnel gap ("neat, but I have no event to add" / "what do I do here?"). ~26 scans produced **zero** submissions.

This plan does four things, decided with Ryan:
1. **Collapses the two parallel "board + approval" systems into one.** Today `/t/:slug` (Tailwind Totem Events page) and `/board/:totem_slug` (standalone Civic Beacon Bulletin Board) are near-mirror images with *opposite* approval defaults and duplicated everything. The Event schema already reserves an unused `provenance: board_submission` value — the merge was anticipated.
2. **Introduces a 5-level role hierarchy** so "anyone can submit, trusted people bypass review" is a first-class rule, with delegated per-totem management.
3. **Adds AI friction-reducers** (suggested events for empty totems; "add an event from a photo") to attack the bottom-of-funnel gap.
4. **Adds a physical-totem short-code** (typed URL fallback for QR skeptics).

### Decisions locked with Ryan
- **Surviving design system: the app's Tailwind theme.** The merged board lives at `/t/:slug` and adopts the bulletin's submission-forward UX (prominent CTA, inline form, upcoming/past rows) *inside* the Tailwind app theme. The standalone `bulletin_board.html.erb` (Civic Beacon) layout is **retired**. → This intentionally reverses the prior "keep the paper-sign look standalone" decision; update memory `project-signal-fire-bulletin-board` after implementation so it isn't later "fixed" back.
- **Canonical URL: `/t/:slug`.** `/board/:totem_slug` and the new `/g/:code` both **301-redirect** to it, so QR codes already in the wild keep working.
- **One model: `Event`.** `BulletinPost` is collapsed into `Event` (it is a weaker subset). Counter-argument (keep two) rejected: dual models force every read path + the approval gate + AI promotion + the moderation queue to be duplicated, directly opposing the "one funnel" goal.
- **Totem admin = lightweight, decoupled from `host_profile`.** A totem admin is a signed-in `User` with a `host_totem_assignment` of `role: totem_admin`. They do **not** need a public host profile. They can (a) approve/edit/delete **any** event on their assigned totems and (b) **assign/invite totem hosts** (existing or brand-new accounts) to those totems — delegated management previously possible only for the super admin.

### The 5 roles
| Role | Stored as | Submit | Auto-publish | Moderate others' events | Assign/invite hosts |
|---|---|---|---|---|---|
| Super admin | `users.is_admin` | ✓ | ✓ (any totem) | ✓ (any totem) | ✓ (any totem) |
| Totem admin | `host_totem_assignments.role = totem_admin` | ✓ | ✓ (assigned totems) | ✓ (assigned totems) | ✓ (assigned totems) |
| Totem host | `host_totem_assignments.role = host` + active `host_profile` | ✓ | ✓ (own events, assigned totems) | ✗ | ✗ |
| User (signed in) | plain `User` | ✓ | ✗ → `pending_review` | ✗ | ✗ |
| Unsigned-in | none | ✓ (anonymous) | ✗ → `pending_review` | ✗ | ✗ |

---

## Phasing & dependencies (reference — Ryan sequences execution)

```
Phase 1 (roles) ─────────────┐
Phase 6 (short-code) ─ indep. │
Phase 2 (model merge) ── gates → Phase 3 (funnel) → Phase 4 (board) → Phase 5 (AI)
                                   needs Phase 1 roles ┘
```
- Phases 1 and 6 are pure additions, independently shippable, need no parks permission or art.
- Phase 2 is the highest-risk (data migration); deploy migration+backfill and keep both URLs reading from `Event` *before* deleting `BulletinPost`.
- Phases 3–5 build on the unified `Event`.

---

## Phase 1 — Role model & authorization

**Migration**
- Add `role` (string, `null: false`, `default: "host"`) to `host_totem_assignments`. Backfill existing rows → `"host"` (all current assignees are hosts, so behavior is unchanged). Safe to deploy ahead of behavior.

**Models**
- `app/models/host_totem_assignment.rb`: add `enum :role, { host: "host", totem_admin: "totem_admin" }, prefix: :role`.
- `app/models/user.rb` — new permission API over the existing `host_totem_assignments` association:
  - `super_admin?` → alias of `is_admin?` (keep the `is_admin` column).
  - `totem_role_for(totem)` → `:super_admin` if `is_admin?`, else the assignment's role symbol or `nil`.
  - `totem_admin_of?(totem)` ; `moderated_totem_ids` → `host_totem_assignments.where(role: :totem_admin).pluck(:totem_id)`.
  - `can_moderate_totem?(totem)` → `is_admin? || totem_admin_of?(totem)`.
  - `can_auto_publish_on?(totem)` → `is_admin?` OR a `totem_admin` assignment OR a `host` assignment **with** `host_profile&.active?` (preserves today's host gate; `totem_admin` is exempt from the profile requirement).
  - `can_manage_hosts_on?(totem)` → `is_admin? || totem_admin_of?(totem)` (for the delegation power).

**Controllers / routes**
- `app/controllers/application_controller.rb`: add `require_totem_moderator!(totem)` and `helper_method`s mirroring the existing `require_admin!`/`require_host!` (:25-35). Leave those two untouched.
- New `app/controllers/totem_admin/` namespace + `TotemAdmin::ApplicationController` (mirror `Admin::ApplicationController` pattern): `require_user!`, then require the user has at least one `role: totem_admin` assignment; per-action scope to `moderated_totem_ids`. Reuse the existing `host` signed-in layout.
- `config/routes.rb`: `namespace :totem_admin` scaffold — a totems index limited to `moderated_totem_ids` now; the moderation queue + host-management land in Phase 3.

**Assignment UI (super admin + delegated)**
- The current per-totem assignment lives only on the host-edit page (`app/controllers/admin/hosts_controller.rb#sync_totem_assignments` :85-97 + `app/views/admin/hosts/edit.html.erb` checkboxes; `host_params` permits `totem_ids: []`). Extend the sync to accept a **per-totem role** (`totem_roles: { totem_id => role }`) — upsert role for selected totems, destroy deselected.
- To assign `totem_admin` to a *non-host* user, the host-edit page isn't the right home. Add `Admin::TotemAssignmentsController` (super admin) — pick any user + totem + role. The host-edit page keeps managing host-role assignments.
- **Delegation (per Ryan's requirement):** `TotemAdmin::TotemAssignmentsController` (or `TotemAdmin::HostsController`) lets a totem admin assign/invite `role: host` users to **their** totems only (scoped to `moderated_totem_ids`). Reuse `app/services/admin/invite_host_service.rb` for inviting brand-new accounts (it already creates the user + host profile + invite email); wrap it with a totem-scope guard. Stamp `assigned_by_admin_id = current_user.id` as today.

**Reused:** `host_totem_assignments` table/association, `Admin::ApplicationController` gate pattern, `InviteHostService`, host layout.
**Net-new:** `role` column, `User` permission API, `TotemAdmin::*` controllers, `Admin::TotemAssignmentsController`.

---

## Phase 2 — Unify the data model (Event becomes the single board record)

**Migration (events)**
- Make `host_user_id` nullable; make `end_time` nullable (FKs stay). Add `submitter_ip` (string, nullable) and optional `submitter_email` (nullable, for "notify me when approved").
- `provenance: board_submission` already exists — no enum change.

**Model (`app/models/event.rb`)**
- `belongs_to :host_user, optional: true`.
- Make `end_time` presence conditional: required for `provenance_host?`/`provenance_admin?`; for `board_submission`/`scouted` default `end_time = start_time + 2.hours` in a `before_validation` (mirrors `Admin::PromoteScoutedEvent::DEFAULT_DURATION`), so `window_state`/`active_now?`/`upcoming_events` keep working unchanged.
- `generate_slug` (:135-144) already uses `totem.slug + title` — works with `host_user_id: nil`.
- **Lock the notification gate:** `enqueue_new_event_jobs` (:120-129) already returns unless `approval_state_published? && provenance_host?` — board submissions never notify. Add a test pinning this so it can't regress.
- Field map BulletinPost → Event: `title`→`title`; `description` (≤160) → `short_description` (≤160, matches the one-line board UX); `starts_at`→`start_time`; status `pending/approved` → `approval_state pending_review/published`; source `public_submission/scouted/admin_added` → provenance `board_submission/scouted/admin`; `submitter_ip`→`submitter_ip`. Convert display-only `recurring`/`recurrence_cadence` to a real RRULE (`weekly`→`FREQ=WEEKLY`, `monthly`→`FREQ=MONTHLY`) so it flows through IceCube — **behavior upgrade**, flagged.

**Data migration / backfill**
- One-time migration: each `bulletin_post` → an `Event` (`host_user_id: nil`, `end_time = starts_at + 2h`, preserve `created_at`, map status/source per above).
- Repoint `scouted_event_candidates.bulletin_post_id` → the existing `event_id` column (schema :165) where a candidate had promoted to a bulletin post; drop `bulletin_post_id` in a later migration.
- Keep `bulletin_posts` read-only during transition; drop the table in a follow-up migration after parity is verified.

**Deprecate (after backfill verified)**
- `Admin::PromoteScoutedEvent.to_bulletin` → redefine to create a `board_submission`/`pending_review` Event; collapse with `.to_totem`.
- Remove `BulletinPost`, `BulletinBoardsController`, `Admin::BulletinPostsController`, `Admin::BulletinPosts::DescriptionsController`, their routes (`routes.rb:26-28,114-120`) and views, the `bulletin_board` layout, and `Totem#bulletin_posts`. `bulletin_board_controller.js` logic migrates to the new funnel controller. Repurpose or drop `totems.bulletin_board_scan_count`.

**Reused:** `provenance: board_submission` (finally used), `approval_state`, `EventTimeAssembly`, slug gen, `PromoteScoutedEvent.to_totem`.
**Net-new:** nullable migration, `submitter_ip`/`submitter_email`, conditional `end_time` default, backfill migration.

---

## Phase 3 — Unified submission funnel + approval gate

**Controllers / routes**
- New `Totems::EventSubmissionsController` — `POST /t/:slug/events`. Mirror `BulletinBoardsController#create` (:24-45) incl. turbo_stream + html paths, but build an `Event`. Reuse the bulletin form's date+time compose (`compose_starts_at` :77-83) for the lightweight public form.
- **Core create branch:**
  ```ruby
  if current_user&.can_auto_publish_on?(totem)
    provenance     = current_user.is_admin? ? :admin : :host
    approval_state = :published
    host_user      = current_user
  else
    provenance     = :board_submission
    approval_state = :pending_review
    host_user      = nil
    submitter_ip   = request.remote_ip   # anonymous + signed-in non-privileged
  end
  ```
  Signed-in non-privileged users: keep `host_user_id` **nil** (don't let a non-host own an event or trip the notification gate); record `submitter_email`/`submitter_ip` for attribution.
- **Moderation queue, reconciled into one:** retire `Admin::BulletinPostsController#approve` and fold into `Admin::EventsController#publish` (:67-70, already flips `pending_review → published`). Add a `?state=pending_review` filter to `Admin::EventsController#index` (:6-18) — this replaces the bulletin pending list.
- **Totem-admin-scoped queue:** `TotemAdmin::EventsController#index` shows `Event.pending_review.where(totem_id: moderated_totem_ids)`; `publish`/`update`/`destroy` constrained to those ids (reuse `Host::EventsController#set_own_event` scoping shape :60-68, but ANY event on a moderated totem, not just own).
- **Spam control:** anonymous create needs per-IP rate-limiting (Rack::Attack throttle keyed on `submitter_ip`) — the old board relied only on human review. Recommended, flagged.

**Routes:** `post "/t/:slug/events" => "totems/event_submissions#create"`; `namespace :totem_admin { resources :events, only: [:index,:edit,:update,:destroy] { member { patch :publish } } }`.

**Views:** `app/views/totems/event_submissions/_form.html.erb` — port `bulletin_boards/_form.html.erb` to Tailwind (date/time/recurring/source_url + the "a person reviews every post" trust line). Turbo-stream success ported from `bulletin_boards/create.turbo_stream.erb` + `_success.html.erb`. Extend `admin/events/index.html.erb` with the pending section; new `totem_admin/events/index.html.erb` + edit.

**Reused:** `events#publish`, `compose_starts_at`, turbo_stream create pattern, host scoping pattern, the two enums.
**Net-new:** `Totems::EventSubmissionsController`, `TotemAdmin::EventsController`, role-based create branch, Tailwind form, rate-limiting.

---

## Phase 4 — Rebuilt totem board page (merge `/t/:slug` + `/board/:totem_slug`)

**Controllers / routes**
- `Totems::BoardsController#show` (:1-30): render a single `show`; load `@active_now`, `@upcoming`, `@past` (add a past read), `@host`, `@favorite`, `@nearby`, and `@event = Event.new` for the inline form. Use `board_empty?` only to decide whether to also show the email-capture + AI-suggestion block, not to fork to a separate template.
- `/board/:totem_slug` → 301 `totem_board_path`. Move/retire the `bulletin_board_scan_count` increment. Redirect or keep `bulletin_boards#index` directory → `/stpete`.

**Views / layout (Tailwind, per decision)**
- Rebuild `app/views/totems/boards/show.html.erb`: masthead → prominent "Add an event here" CTA → inline submit panel (Phase 3 form) → Active-now / Upcoming rows → "Earlier" past rows → host story → nearby carousel → footer. Keep existing partials `_active_now_section`, `_upcoming_section`, `_event_card`, host story, favorites, account nudges.
- New `_past_section.html.erb` (port the bulletin "EARLIER" rows into Tailwind).
- Empty state: fold `empty.html.erb`'s email capture (:27-39) + the submission CTA + AI suggestions (Phase 5) into the unified `show`.
- New Stimulus `event_submission_controller.js` (port `bulletin_board_controller.js`: open panel, toggle cadence — Tailwind classes). Retire `bulletin_board.html.erb`.

**Reused:** all `totems/boards` partials, favorites, nearby carousel, host story, account nudges, email capture, `bulletin_board_controller.js` logic.
**Net-new:** merged `show.html.erb`, `_past_section`, `event_submission_controller.js`, redirects.

---

## Phase 5 — AI friction-reducers

**5a. AI-suggested events (empty/sparse totems)**
- Reuse `Ai::EventScout` + `ScoutRun` + `EventScoutJob` + `scout_status_controller.js`. New `TotemAdmin::ScoutsController#create` mirroring `Admin::ScoutsController#create` but scoped to `moderated_totem_ids`. Surface candidates in the board's empty-state block ("AI-suggested — add to board?") calling `PromoteScoutedEvent.to_totem` (now lands a `board_submission`/`pending_review` Event). Moderator/super-admin only — anonymous visitors don't trigger scouts (cost control, $20/mo cap noted in `open_router_client.rb:13`).

**5b. Add event from photo (net-new)**
- New `Ai::EventImageExtractor`: base64 image → `OpenRouterClient.chat` with a vision model and a multimodal `messages` array:
  ```ruby
  { role: "user", content: [ {type:"text", text: prompt},
    {type:"image_url", image_url:{url:"data:image/jpeg;base64,..."}} ] }
  ```
  `response_format: json_schema` reusing the single-event shape of `Ai::EventScout::SCHEMA`. `OpenRouterClient.chat` passes `messages` through unchanged → **no transport change**. Vision model id as a service constant (e.g. `google/gemini-2.5-flash`, non-`:online`).
- Endpoint `POST /t/:slug/events/from_photo` → returns JSON to pre-fill the submission form (mirror the description-assist JSON-no-persistence pattern). **Do not persist the image** — base64 in-request only, no ActiveStorage. Extracted data still flows through the Phase 3 create path → approval gate (anonymous photo submissions stay `pending_review`).
- New Stimulus `photo_extract_controller.js` (file input → POST → fill fields).

**Reused:** `EventScout`/`ScoutRun`/`EventScoutJob`/`scout_status`, `PromoteScoutedEvent`, `OpenRouterClient.chat` vision pass-through, `EventScout::SCHEMA`, description-assist JSON pattern.
**Net-new:** `Ai::EventImageExtractor`, photo endpoint, `photo_extract_controller.js`, `TotemAdmin::ScoutsController`.

---

## Phase 6 — Physical totem short-code (Q1/Q3, already decided)

**Migration / model**
- Add `short_code` (string, nullable, unique index) to `totems`. **Store as string** (leading zeros; lets length grow 2→3 digits later with no migration). Generate on create via a uniqueness-retry loop mirroring `Totem#generate_slug` (:64-73). Globally unique (matches the global-slug model; single city today). Backfill existing totems.

**Routes / controller**
- `get "/g/:code" => "totems/short_codes#show"` → find by `short_code` → **301** to `totem_board_path(totem.slug)`; 404 on miss. New `Totems::ShortCodesController`. Dedicated `/g/` prefix is required — a bare numeric at `/t/:slug` is ambiguous (slug regex allows digits; a slug could literally be `"42"`).
- Pass `?source=short_code` on the redirect so `AnalyticsService.track` in `boards#show` distinguishes typed-code vs QR entry.

**Admin form / display / QR**
- `Admin::TotemsController#totem_params` (:67-69): permit `:short_code`. `app/views/admin/totems/_form.html.erb`: field showing the generated value, manual override allowed (uniqueness-validated).
- New `short_qr` member action mirroring `qr`/`board_qr` (:40-59) encoding `totem_short_code_url(code)`. **Encode the short URL in the QR** — lower density → prints more reliably small on hand-fabricated art, and keeps the printed number + QR consistent.
- Typo note: with few totems most 2-digit codes resolve to a *valid* (wrong) totem, so a fat-finger silently lands elsewhere. Not solved here; revisit a confirmation interstitial or check character if mis-entry shows up in analytics.

**Reused:** slug-gen uniqueness pattern, `RQRCode` QR pattern, totem admin form/controller, the `source` analytics param.
**Net-new:** `short_code` column, `/g/:code` route + controller, admin field, `short_qr` action.

---

## Reconciliations / contradictions flagged
- **Opposite approval defaults** (Event `published` vs Bulletin `pending`) → unified rule: submissions default `pending_review` unless the submitter has auto-publish rights on that totem.
- **Two design systems** → Tailwind app theme survives; Civic Beacon retired (reverses prior intentional decision — update memory).
- **Memory `project-signal-fire-bulletin-board`** documents the standalone look + edit-enabled as intentional; the standalone-look note is now superseded.
- **AI Scout's dual targets** (`add_to_totem` / `add_to_bulletin`) → collapse to a single Event target.
- **City hardcoding** (`stpete` in `BulletinBoardsController`, `/stpeteboards` directory) → out of scope, but note a globally-unique short code + global slugs will both need rethinking if a second city appears.
- **Timezone**: bulletin hardcodes `America/New_York`; events use `EventTimeAssembly` → unify on the latter.

## Verification
- **Test runner:** Minitest via `bin/rails test` / `bin/ci` (rubocop + brakeman + tests). There is **no docker-compose test harness** — per project env notes, run the suite in a `ruby:3.4.7-slim` container against a `postgres:16` container using `db:create db:migrate` (NOT `db:prepare`/seed). Confirm whether to enable the currently-commented Capybara system tests for the funnel.
- **Phase 1:** `User#totem_role_for` / `can_moderate_totem?` / `can_auto_publish_on?` / `can_manage_hosts_on?` across all 5 levels (incl. host-profile-active requirement for `role: host`, decoupling for `role: totem_admin`); role enum + backfill default; `TotemAdmin::ApplicationController` rejects non-moderators; delegated host-invite is totem-scoped.
- **Phase 2:** Event accepts nullable `host_user_id`/`end_time`, defaults `end_time`; `enqueue_new_event_jobs` does NOT fire for `board_submission`/`pending_review`; backfill parity (bulletin_posts → events); `PromoteScoutedEvent` lands a pending board-submission Event.
- **Phase 3 (funnel):** create as (a) anonymous → `board_submission`/`pending_review` + ip; (b) signed-in plain → pending, no `host_user_id`; (c) totem_host → published; (d) totem_admin → published; (e) super_admin → published. Moderation scoping: `TotemAdmin::EventsController` cannot touch non-moderated totems. Template off `test/controllers/bulletin_boards_controller_test.rb`.
- **Phase 4:** `show` renders form + upcoming/past; `/board/:slug` 301s; empty state shows capture + CTA. Integration walk: visit `/t/:slug` → submit anonymously → appears in admin/totem-admin queue → publish → visible.
- **Phase 5:** `Ai::EventImageExtractor` with an injected fake `http_client` (reuse the `OpenRouterClient` seam as `EventScout`/`DescriptionAssistant` tests do) asserting vision message shape + schema parse + nothing persisted; totem-admin scout authorization.
- **Phase 6:** `short_code` uniqueness/generation; `/g/:code` 301 to canonical with `source=short_code`; admin permits `:short_code`; `short_qr` returns a PNG.
- **Manual end-to-end:** `bin/dev` → visit `/g/:code` → `/t/:slug` → "Add an event here" → submit anonymously → confirm hidden (`pending_review`) → totem-admin queue → publish → reload → appears in Upcoming. Repeat as totem_host (auto-publish). Test photo prefill with a sample flyer.

## Post-implementation follow-up
- Update memory `project-signal-fire-bulletin-board` (standalone Civic Beacon look is superseded; board now unified into the Tailwind `/t/:slug` page) and `project-signal-fire-env`/bulletin notes referencing `/board/:slug`.
