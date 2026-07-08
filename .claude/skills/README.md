# Skill library — CPT Unified St. Pete Calendar (Signal Fire codebase)

Written July 2026 as the departing lead's handoff. Audience: engineers and AI
sessions with zero prior context. Each skill is self-contained and cites real file
paths; when a skill and the code disagree, **the code wins** — fix the skill.

| Skill | Load it when… |
|---|---|
| [project-compass](project-compass/SKILL.md) | Deciding WHAT to build or WHY — scope, sequencing, monetization, roadmap (Crawl/Walk/Run), locked decisions, working with Ryan |
| [codebase-map](codebase-map/SKILL.md) | Orienting: where things live, domain model, namespaces, the Totem-means-venue vocabulary rule |
| [event-domain](event-domain/SKILL.md) | Touching Event/Totem models, event queries, visibility, recurrence, check-ins, or notification fan-out — the invariants live here |
| [dev-loop](dev-loop/SKILL.md) | Setting up, running tests, linting, committing, PRs, deploys — including this repo's WSL and no-CI quirks |
| [safe-changes](safe-changes/SKILL.md) | Any migration, route/API change, backfill, or PR about to auto-deploy to production — the DO-NOT-BREAK contracts |
| [ai-pipelines](ai-pipelines/SKILL.md) | Event scouting, photo extraction, description assist, OpenRouter config, AI cost/abuse guardrails |

Suggested reading order for a brand-new contributor: codebase-map → dev-loop →
project-compass, then event-domain + safe-changes before your first PR.

Known gaps in the code (found during handoff; the visibility-gate leaks, the
serializer 500, and the admin-provenance quirk were fixed 2026-07 in the
trust-gate hardening PR — full detail in `safe-changes` and `event-domain`).
Still open: API serializers hardcode `signalfire.live` URLs (owned by the brand
isolation PR); `Event#weekly?` misreads `INTERVAL=10..19`; cancelling a recurring
event sends no cancellation notice.
