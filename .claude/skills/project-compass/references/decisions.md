# Decision log — CPT calendar pivot (2026-07-02)

Each entry: the call, the rejected alternative, and the tradeoff accepted. These were
made deliberately with Ryan; don't reverse them silently. If reality contradicts a
premise below, surface it to Ryan — that's how these got made in the first place.

## 1. Thesis: provenance-tiered aggregation (not curation-first)

**Rejected:** curation-first (host-verified only, aggregate later); full aggregation
with verification as an afterthought.

**Reasoning:** curation-purity's distribution channel was the physical totem — you
curated *because* the surface was a specific trusted place. That channel was
field-invalidated (people don't scan QR codes at locations). Pure curation on a web
calendar is just a small calendar: can't be "unified," can't generate merger leverage.
Full aggregation without labels is the scraper-slop competitor set.

**Accepted cost:** a permanent listings-maintenance operation (freshness, duplicates,
dead links, weekly hand-killing of bad listings). This is the recurring price of
breadth; it was accepted knowingly.

**The tier ladder (user-facing):**
- **Verified host** — identity known to us. Earned, free, forever.
- **Business / Partner** (name workshoppable, never "Verified") — paid subscriber;
  buys presentation and reach (enhanced profile, outline treatment, promoted
  placement), NOT truth status.
- **Community-submitted** — the anonymous board-submission funnel, moderated.
- **Found** — AI-scouted; labeled with source link and a "confirm before you go" note.

## 2. "Verified" is never for sale

Ryan's initial framing had the paid tier adding "a verification check or blue
outline." The departing lead pushed back and Ryan accepted the reframe: provenance
(is this real, do we know the poster) and payment (who pays us) are separate axes.
If verification is purchasable it stops being a trust signal — the paid-blue-check
failure mode — and the label system is the product's one differentiator against
scraper competitors. Same revenue, uncompromised trust: sell presentation, not truth.

Corollary: **promoted/boosted events are explicitly labeled distinct slots** in the
ranking (e.g., max one promoted card per day-group), never invisible ranking boosts.
The ranking function should be written with a labeled promoted-slot concept from day
one; the schema for it is deliberately NOT built until Run.

## 3. Event-first IA (conscious reversal of place-first)

Signal Fire chose place-first deliberately (evaluate the location before the
activity) — that logic served a user physically standing at a place. A calendar user
asks "what's on Thursday," not "what's happening at Williams Park." Home = filterable
citywide calendar; venue pages demote to secondary surfaces (SEO landing pages + the
trust detail view). Printed QR codes in the field still resolve to venue pages.

## 4. Keep the Rails app; defer the Totem→Venue rename

The rebuild-from-scratch option was pressure-tested and rejected: the app already had
provenance/approval, submissions, scouting, auth, recurrence, notifications, consoles.

The physical rename (table/model/associations) was *initially* recommended, then
reversed when measured: 204 files reference "totem," and the frozen Expo app consumes
`/api/v1/totems` with totem-keyed JSON. A physical rename = giant diff + prod table
rename + permanent API compat shim. Instead: **product/UI language says "venue"; code
says Totem**; the mapping is documented in the `codebase-map` skill. The mechanical
rename is a dedicated chore PR at a natural boundary (mobile unfreeze / API v2).
Lesson encoded: measure blast radius before recommending refactors.

Schema note: `events.totem_id` stays NOT NULL — every event needs a place; new venues
are just created freely (including from scouted events).

## 5. Monetization ladder: subscriptions → promoted slots → ticketing

Ordered by risk, not by revenue potential:
1. **Business subscription** — simple recurring billing (provider-hosted checkout);
   no payouts, refunds, or chargebacks. Ship when there are businesses to sell to (Run).
2. **Promoted slots** — same billing rails, labeled inventory.
3. **Ticketing** — the only item that makes CPT a payments intermediary (marketplace
   payouts, refunds, chargebacks, fees, tax reporting). **Demand-gated**: build when
   several hosts concretely ask. The 20% precursor is free RSVP with capacity +
   waitlist — no payments at all.

**Legal flag (unresolved, blocking for ticketing):** "donations" configured by hosts
who aren't registered nonprofits are not tax-deductible charitable gifts. Labeling is
a legal question. Professional review required before any donation feature ships.
Do not present this as settled; do not let a future session ship it casually.

## 6. Mobile app frozen

One frontend during the pivot sprint. The Expo app stays deployed and functional; the
`/api/v1` contract stays stable (see `safe-changes` skill); zero new mobile work until
post-traction. Revisit at Run.

## 7. Recommendations: earn personalization

Launch order: content-based ranking (category, time-of-week, neighborhood, host
follows) + "popular this week" (RSVP counts) → behavioral personalization only after
RSVP volume exists. The RSVP button is Phase-1 infrastructure precisely so the data
accumulates; the recommender itself is a luxury until then. A recommender must never
breach notification discipline (~1 push/user/week, ceiling 3).

## 8. Taxonomy: minimal by design

One flat level, ~10–12 categories, exactly one required per event, defined in a code
constant (not a table — code is as editable as an admin UI here, and categories change
rarely). No tags, no subcategories, no interest graphs at launch: that maintenance
sink was cut once in the totem era and stays cut. Category list itself is workshopped
with Ryan at build time.

## 9. Host onboarding: self-serve with a claim funnel (Walk)

Anyone can create a host account; the existing `pending_review` gate moderates their
first event, then auto-publish. Scouted events become **claimable** ("Is this your
event? Claim it") — converting aggregated listings into verified hosts. The
aggregation pipeline doubles as the host-acquisition funnel.

## Open questions (genuinely unresolved as of 2026-07-02)

- The new brand name and domain (Ryan will workshop; brand tokens are isolated so the
  swap is one PR).
- What SPDP wants in exchange for distribution; what the news contact can offer
  concretely.
- Dedup strategy quality bar for citywide scouting (see roadmap-walk.md).
- Exact category list.
