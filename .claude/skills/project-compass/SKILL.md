---
name: project-compass
description: Use when making any product, scope, sequencing, or strategy decision on this project — what to build next, whether a feature belongs, how to rank/label events, monetization, or anything touching the roadmap. Load this BEFORE proposing new work.
---

# Project Compass — CPT Unified St. Pete Calendar

This is the strategy core of the project, written by the departing lead. The code
tells you what exists; this tells you why, what's next, and what standard to hold.

## The one-paragraph story

Signal Fire (this codebase) was physical QR "totem" markers at gathering spots
surfacing a live event board. Field testing invalidated the QR-entry thesis, and
in July 2026 the project pivoted: same Rails app, new mission — the **unified
St. Pete event calendar** under the Community Play Tools (CPT) banner. Breadth
via aggregation, trust via honest provenance labels, in a plain civic voice.
Brand name TBD (workshopped with Ryan); until the swap, product language is
"venue"/"calendar" even where code says "totem"/"board".

## Locked decisions (do not relitigate; reopen only if Ryan asks)

| Decision | Call | Why |
|---|---|---|
| Thesis | Provenance-tiered aggregation | "Unified" needs breadth; labels keep it honest; machinery already existed |
| IA | Event-first | Home = filterable citywide calendar; venue pages are secondary SEO/trust surfaces. Conscious reversal of place-first |
| Monetization | Business subscription tier + labeled promoted slots, then ticketing | Subscriptions = simple billing, no marketplace risk. Ticketing is demand-gated fast-follow |
| **"Verified" is never for sale** | Paid tier buys presentation/reach ("Business"/"Partner"), NOT truth status | Provenance answers "is this real / do we know the poster" — if purchasable, every label dies. The paid-blue-check failure mode |
| Promoted content | Always explicitly labeled, distinct slots | Never secret ranking juice |
| Codebase | Keep this Rails app; no rebuild | Rebuild was measured and rejected — most substrate existed |
| Totem→Venue rename | **Deferred** (presentation-layer only) | 204 files + frozen mobile API contract; rename is a later dedicated chore PR |
| Mobile app | Frozen, not killed | API stays stable; no new Expo work until post-traction |
| Ticketing "donations" | Legal review BEFORE shipping | Non-nonprofit hosts' "donations" aren't tax-deductible; labeling is a legal question |

Details and rationale: [references/decisions.md](references/decisions.md)

## Roadmap

- **Crawl** — the first demoable slice: taxonomy, RSVP, calendar home, SEO, brand isolation.
  [references/roadmap-crawl.md](references/roadmap-crawl.md)
- **Walk** — population + distribution (the traction sprint): scheduled citywide scouting
  with dedup + spend caps, claim flows, host self-serve, SPDP widget, news beat, recs v0.
  [references/roadmap-walk.md](references/roadmap-walk.md)
- **Run** — monetization + intelligence, each item demand-gated: subscriptions, promoted
  slots, behavioral recs, ticketing, mobile/rename revisit.
  [references/roadmap-run.md](references/roadmap-run.md)

**Traction, defined** (what Ryan shows on his phone, not a deck): a live week with real
density — order of 50+ events across 20+ venues, visible RSVP counts, weekly uniques
trending up, the SPDP widget live or committed.

## Operating principles (the standard)

1. **Solo-founder capacity is the binding constraint.** Smallest thing that proves the
   next assumption. For every large proposal, also give the 20%-effort version.
   When in doubt, subtract.
2. **Notification discipline:** ~1 push per active user per week, hard ceiling 3,
   never send a weak push. A recommender makes this easier to violate — don't.
3. **One-signal calm design:** the surface stays quiet so "happening now" carries weight.
4. **Plain civic voice:** if a neighbor wouldn't say it, don't write it.
5. **Provenance integrity:** every listing honestly labeled; verified is earned, free.
   Every new public read path applies the visibility gate (see `event-domain` skill).
6. **Sequence before building:** gate high-cost / hard-to-reverse work (payments,
   institutional dependencies, scheduled AI spend) on confirmed demand or permission.
7. **The code wins.** Verify claims against the repo before acting on any summary —
   including this one. Measure blast radius (grep first) before recommending refactors.
   Recommend directly, name what you're trading against.
8. **Don't fabricate.** No invented competitor facts, market sizes, or provider API
   syntax. Verify externally or ask Ryan.

## Working with Ryan

Solo founder, basic-to-intermediate technical, implements with Claude Code. Named risks:
procrastination and over-engineering — your job is to police both. He wants direct
recommendations and honest pushback, not hedged option menus; he confirms or declines
fast. Money/tax/legal questions get flagged for professional review, never resolved
by assumption.

## Context that decays — verify before relying

Competitive facts as of 2026-07: merger counterparty whatsgood.city verified as B2B
("AI-Powered Event Discovery for Destinations" — a vendor to destination-marketing
orgs, which makes the SPDP relationship defensively urgent and merger logic
complementary). discoverdowntown.com = legacy incumbent (Ryan's read: dated tech;
unverified). Assets: SPDP relationship (Jason Mathis, CEO), a local news contact.
All of this moves — re-verify before building strategy on it.
