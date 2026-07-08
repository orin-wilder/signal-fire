# Handoff — for Ryan

*July 2, 2026. This is the one page written for you, not for future AI sessions.
Everything technical and strategic lives in `.claude/skills/README.md` and travels
with the repo; any Claude Code session (Sonnet-class included) will load it
automatically. When a skill and the code disagree, the code wins — have the
session fix the skill.*

## Where things stand

The pivot is decided and planned, nothing is built yet. Locked: provenance-tiered
aggregation with a paid Business/Partner tier (verification itself is never for
sale), event-first IA, demand-gated ticketing, new brand on the same Rails app,
mobile frozen. The Crawl/Walk/Run roadmap is written and adversarially reviewed.
Handoff verification also found real production bugs — see the decision queue.

## Your decision queue (only you can clear these)

1. **Trust-gate hardening PR — go/no-go.** Six public read paths skip the
   visibility gate today; the weekly digest can push an unreviewed event title to
   phones, and the mobile API has a latent 500. My recommendation: fix before
   Crawl PR 1 (it's now "PR 0" in the roadmap). Small, no migration.
2. **Admin-provenance ruling.** Events created in the admin console silently carry
   `host` provenance and DO notify followers. Intended or bug? One word from you
   unblocks the fix either way.
3. **The name.** Brand tokens will be isolated in Crawl PR 5; the swap is one PR +
   DNS once you pick. Until then everything ships under the current domain.
4. **Category list.** ~10–12 flat categories, workshopped in five minutes at the
   start of Crawl PR 1. A candidate list is in the roadmap.
5. **SPDP + news contact asks.** What does Jason Mathis actually want in exchange
   for distribution? What can the news contact concretely run? Walk's Tracks 3–4
   are sized to whatever the answers are.

## Ops checklist (15 minutes, before the first build session)

- [ ] Verify `OPENROUTER_API_KEY` is set on Render (was unset as of June; AI
      features silently no-op without it).
- [ ] Check the OpenRouter account's monthly spend cap — a code comment claims
      ~$20/mo but nothing enforces it in-app.
- [ ] Docker Desktop must be running before any local test session (Postgres
      lives in `compose.yml` now).
- [ ] Commit this handoff: the skill library + HANDOFF.md are sitting untracked
      in your working tree. Branch → PR → your review, per your own rule.

## The first three sessions (copy-paste to start)

**Session 1:** `Read .claude/skills/README.md, then execute PR 0 from
.claude/skills/project-compass/references/roadmap-crawl.md (trust-gate
hardening). Open a PR; don't merge.`

**Session 2:** Crawl PR 1 (taxonomy) — workshop the category list with the
session first, then let it build.

**Session 3:** Crawl PR 2 (RSVP). After that the calendar home (PR 3) is the
flagship — 2–3 sessions on its own.

Cadence check: Crawl is ~6–8 sessions total. If a week passes with zero sessions,
that's the procrastination risk you named — the antidote is that every PR above
is small enough to finish in one sitting.

## One warning worth repeating

The breadth thesis you chose has a permanent cost: expect to hand-kill bad
listings weekly once citywide scouting runs. Budget the time; it's the price of
"unified," and the honest labels only stay honest if someone tends them.

Good luck. The calendar is a better idea than the totems were — and the totems
are why you know that.
