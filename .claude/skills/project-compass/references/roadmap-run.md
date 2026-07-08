# Run — monetization + intelligence (each item demand-gated)

**Goal:** revenue and durability. Nothing in Run starts on a schedule; every item has
an explicit **gate** — a real-world signal that must be true first. If a gate isn't
met, the item waits. This is the phase where over-engineering risk peaks: the
calendar works, and idle hands will want to build platforms. Don't.

**Entry condition:** Walk's exit criteria met (density sustained, distribution live).

## 1. Business/Partner subscription tier

**Gate:** claimed venues / recurring hosts exist in enough volume that there is
someone to sell to (Walk Track 2 produces the warm-lead list).

- Monthly subscription for businesses/organizations. **Never named "Verified"** —
  it buys presentation and reach, not truth status (locked decision; see
  decisions.md #2).
- Perks: enhanced venue/host profile (brand styling, outline treatment, links,
  imagery), a promoted-placement allotment, maybe early analytics.
- Billing: provider-hosted checkout + subscription management (capability level —
  verify the current provider's docs at build time; do not design against remembered
  API syntax). Simple SaaS billing only: no payouts, no marketplace machinery.
- Data model lands HERE, not before: plan/subscription fields (or a small
  organizations table if claiming produced real multi-venue operators).
- **20% version:** a "Partner" badge + enhanced profile sold via a manual monthly
  invoice to the first 3–5 businesses. Validate willingness-to-pay before building
  billing automation.

## 2. Promoted slots

**Gate:** at least a handful of subscribers (it's an upsell, not a standalone).

- Labeled placement in the calendar ranking — explicit distinct slots (e.g., max one
  promoted card per day-group), never invisible ranking boosts (locked decision).
- Inventory rules + simple buyer-facing reporting (impressions/clicks from the
  existing analytics events).
- Schema: `events.promoted_until` or a small promotions table — decided at build time.

## 3. Behavioral recommendations

**Gate:** months of RSVP volume (thousands of RSVPs, not hundreds).

- Co-RSVP similarity ("people who go to what you go to also go to…"), personalized
  digest ordering, maybe a "for you" rail.
- Still content-signal-first where data is thin; personalization augments, never
  replaces, the popular/category rails.
- **Hard rule carried forward:** notification discipline (~1 push/user/week, ceiling
  3) binds the recommender. Personalization changes what's in the digest, never how
  often anything sends.

## 4. Ticketing

**Gate:** several hosts have concretely asked to sell tickets or collect money.
This is the highest-risk item in the entire roadmap — it makes CPT a payments
intermediary (payouts, refunds, chargebacks, platform fees, tax reporting).

- **Precursor (cheap, do first):** free RSVP with capacity + waitlist. No payments,
  and it may satisfy most of the actual demand.
- **Legal review is blocking, not advisory** (locked decision): "donations" to hosts
  who aren't registered nonprofits are not tax-deductible charitable gifts — labeling
  and money-flow need professional review before anything ships.
- Architecture at capability level: marketplace-payout model where the payments
  provider carries merchant-of-record duties (verify current provider docs at build
  time). Order/payment records get their own tables, designed then.
- Platform fee decision (flat vs %) is Ryan's, made with real host conversations.

## 5. Platform debts, revisited at Run

- **Mobile unfreeze decision:** if yes, that's the natural moment for an API v2 and…
- **…the Totem→Venue mechanical rename** (deferred from the pivot; ~200-file chore
  PR; see decisions.md #4). Also purge hardcoded `signalfire.live` URLs from
  API serializers (known gap — see `safe-changes` skill).
- **Materialized occurrences table** if event volume hits the Ruby-expansion ceiling
  (calendar pages slow / hundreds of recurring events — see `event-domain` skill).
- **Dedup hardening** from heuristic-with-review to trusted auto-merge, if Track 1
  data supports it.

## What "done" looks like for Run

Recurring revenue from subscriptions covering infrastructure + AI spend; promoted
slots sold without eroding trust labels; the merger/partnership conversation — if
still relevant — happening from strength (a revenue-bearing consumer surface + DMO
distribution vs. their B2B pipeline). Re-verify the competitive landscape before
leaning on it; it will have moved.
