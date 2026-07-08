# Walk — population + distribution (the traction sprint)

**Goal:** density and reach. Any given week looks *alive*, and the calendar is
visible where St. Pete already looks — SPDP's site, the local news beat, search.
Walk is what creates merger leverage: the counterparty (whatsgood.city) sells event
discovery to destination-marketing orgs B2B, so **DMO-visible traction (the SPDP
widget) counts double** alongside consumer numbers.

**Entry condition:** Crawl's definition of done is met. **Exit criteria (traction,
concretely):** ~50+ events/week across 20+ venues sustained for a month · weekly
uniques trending up · SPDP widget live (or formally committed) · news beat recurring ·
a meaningful share of Found events claimed by their hosts.

Tracks below are ordered by dependency, not strict sequence — 1 and 2 are the spine;
3–5 attach to them. Each has a 20%-effort version; start there when in doubt.

## Track 1 — Citywide scheduled scouting + dedup (the hard engineering)

Today the scout is per-venue and moderator-triggered. Walk makes it scheduled and
citywide. This is where aggregation earns its cost, and it ships with guardrails or
not at all (locked decision — see `ai-pipelines` skill):

- **Scheduler:** Solid Queue recurring task (`config/recurring.yml` pattern already
  used by the weekly digest) running venue/category sweeps.
- **Spend cap + kill switch (MUST ship with the scheduler):** a monthly budget ledger
  (count runs × known per-run cost), hard stop when exceeded, and a single env-var/
  setting kill switch. The scout calls a paid web-search model; an unattended loop
  without a cap is an open wallet.
- **Dedup (the actual hard problem of every aggregator):** same event found twice, or
  scouted + host-posted. Heuristic matching on normalized title + date + venue
  (trigram similarity is available in Postgres); matches land in the existing review
  queue as "possible duplicate" rather than auto-merging. Auto-merge only after the
  heuristic proves precise in review.
- **Staleness:** Found events get a re-verify-or-expire policy (e.g., auto-unpublish
  N days after their source was last confirmed); periodic dead-link check on
  `source_url`. Every stale listing a user hits erodes the whole calendar.
- **20% version:** a weekly manual scout run across all venues via the existing admin
  UI, with a written checklist and manual duplicate scan. Do this for 2–3 weeks
  first — it calibrates the dedup heuristic against real data before you automate.

## Track 2 — Claim funnel + host self-serve

- **Host self-serve signup:** public host registration (today host accounts are
  admin-invited). The existing `pending_review` gate moderates a new host's first
  event; after first publish, they auto-publish. Moderation load stays bounded.
- **Event claiming:** "Is this your event? Claim it" on every Found listing → email
  verification against the source / lightweight review → provenance upgrades to host,
  account created. **The aggregation pipeline doubles as the host-acquisition
  funnel** — this is the strategic point of Track 2.
- **Venue claiming:** businesses claim their venue page (presages the Run-phase
  subscription tier — a claimed venue is a warm lead). Note: `totems.active`
  defaults to false; venue-creation flows must handle activation.
- **20% version:** claim = a mailto link + manual admin flip of provenance. Ship the
  *label* ("Is this yours?") before the machinery.

## Track 3 — SPDP embed widget (DMO-visible traction)

- An embeddable, brand-lite iframe of a filtered calendar view (e.g., downtown
  neighborhood), cache-friendly, instrumented separately so widget traffic is
  provable in the merger/partnership conversation.
- Pitch framing that already works institutionally: "we funnel people toward real,
  permitted gatherings; we don't bypass them."
- **20% version:** IS the v1 — an iframe of an existing filtered calendar URL with a
  compact layout param. A session of work. Pull this forward if the Jason Mathis
  conversation happens early — and if that happens **before Crawl PR 3 ships**, the
  right move is to reorder Crawl (build PR 3's calendar view next, then the iframe),
  not to build a bespoke widget on the old place-first board. The widget is a window
  onto the calendar; it has nothing to show until the calendar exists.

## Track 4 — News beat

- A recurring "what's on this week" surface the news contact can run: a public
  `/this-week` view + an exportable digest (email/RSS), every event linking back.
  Recurring inbound links + a weekly deadline that forces population discipline.
- **What the contact can actually offer is unverified — confirm with Ryan before
  building beyond the 20% version:** the public page + a manually sent email.

## Track 5 — Recommendations v0 (no ML, no new infra)

- "Popular this week" rail: RSVP counts, already collected since Crawl PR 2.
- Category affinity: "more like what you're going to" — content-based on the
  categories/neighborhoods of a user's RSVPs + existing host follows.
- Re-point the existing weekly digest at the citywide calendar, RSVP-aware.
- Hard rule: recommendations never breach notification discipline (~1 push/user/week,
  ceiling 3). Recs change what's IN the digest, not how often anything sends.
- Behavioral/collaborative personalization is explicitly deferred to Run.

## Risks to watch during Walk

- **OpenRouter spend** (Track 1 caps are non-negotiable).
- **Listings quality erosion** — expect to hand-kill bad listings weekly; that's the
  accepted cost of the breadth thesis, budget the time.
- **SPDP dependency** — the widget is leverage, not a platform bet; the calendar must
  stand alone if the relationship stalls.
- **Scope creep** — every track has a 20% version for a reason. Solo founder.
