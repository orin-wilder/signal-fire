---
name: dev-loop
description: Use when setting up the local environment, running or debugging tests, linting, committing, opening PRs, or deploying/verifying a deploy of this Rails app. Covers the WSL2 quirks (git identity, /mnt/c permissions), the no-CI reality, and Render deploy mechanics.
---

# Dev loop — environment, tests, PRs, deploys

Environment: Windows 11 + WSL2 (Ubuntu), repo lives on the Windows filesystem at
`/mnt/c/Users/ryanm/Documents/Claude/signal-fire`. That mount causes most of the quirks below.

## Toolchain (already installed — do not reinstall)

- **Ruby 3.4.7** via **mise** (`~/.local/bin/mise`), honoring `.ruby-version`. Non-interactive
  shells don't get mise automatically — **prefix every Ruby/Rails command**:
  ```bash
  eval "$(~/.local/bin/mise activate bash)" && bin/rails test
  ```
- **PostgreSQL 16 via Docker Compose** (`compose.yml`), reachable at `localhost:5432`.
  Requires Docker Desktop running on Windows with WSL integration enabled — starting it is a
  **human step**; if `docker` is "not found in this WSL 2 distro", ask the user to start Docker
  Desktop. Then: `docker compose up -d --wait`. There is no native `psql`; the pg gem connects directly.
- `.env` (copied from `.env.example` by `bin/setup`) supplies `PGHOST/PGPORT/PGUSER/PGPASSWORD`.

## Cold start (in order)

```bash
docker compose up -d --wait                                        # Postgres (needs Docker Desktop up — human step)
eval "$(~/.local/bin/mise activate bash)" && bundle install        # gems (bin/setup does this + .env copy + db:prepare)
eval "$(~/.local/bin/mise activate bash)" && bin/rails db:prepare
```

## Tests

```bash
eval "$(~/.local/bin/mise activate bash)" && RAILS_ENV=test bin/rails db:prepare                 # once per schema change
eval "$(~/.local/bin/mise activate bash)" && bin/rails test                                      # full suite
eval "$(~/.local/bin/mise activate bash)" && bin/rails test test/models/event_test.rb            # one file
```

There are **no system tests** (`test/system/` doesn't exist) and no Chrome/Chromium is installed
in this WSL distro — `bin/rails test:system` has nothing to run. If you add system tests, you
also own installing a browser + driver here.

**Baseline discipline — establish before blaming your change.** Last verified baseline
(2026-06-19, post-Phase-6 main): **724 runs, 0 failures, 0 errors** — fully clean. Main has moved
since (PRs #13–#18), so on your first session: run the suite on a clean main checkout FIRST and
record the result. Any failure after your change that wasn't in your baseline is yours.
(Historical note: older docs mention "6 pre-existing failures" — that was a Phase-2-era branch,
long fixed. Main is expected clean.)

Local green **is** the merge bar — there is no CI (see below).

## Lint

RuboCop (Rails Omakase) is configured, **but** the codebase has de-facto no-space array brackets
(`[:index]`) while Omakase wants `[ :index ]`. There is drift and no CI gate.
- **Never blanket-run `rubocop -a` on touched legacy files** — it sweeps unrelated lines into your diff.
- Match the style of neighboring code. Run rubocop only on files you created, or targeted cops.

## Git + PRs (WSL quirks matter)

- Identity: `.git/config` already carries a working `[user]` block (verify:
  `git var GIT_AUTHOR_IDENT`) — a plain `git commit` normally does the right thing.
  Historical note (June 2026): `.git/config` writes intermittently failed on /mnt/c with a
  `config.lock` chmod error; this no longer reproduces, but **if** you hit it, don't fight it —
  set identity per command via `GIT_AUTHOR_NAME/EMAIL` + `GIT_COMMITTER_NAME/EMAIL` env vars.
- Beware CRLF churn: if `git status` suddenly shows hundreds of modified files with no content
  change, it's line endings — do not commit or stash-drop real work with it. Diff before staging.
- **main is branch-protected**: no direct pushes. Full flow:
  ```bash
  git checkout -b my-feature && git add -A && git commit -m "..."
  git push -u origin my-feature
  gh pr create --title "..." --body "..."
  ```
- **Do NOT self-merge.** Open the PR and stop; the user (Ryan) reviews and merges. This is an
  explicit standing instruction (2026-06-22), even though branch protection technically allows self-merge.
- **CI never runs**: `.github/workflows/ci.yml` exists but this repo is a fork and Actions were
  never enabled, so **zero checks report on PRs**. Don't wait on `gh pr checks` — verify locally.
  If Actions get enabled later, expect the `lint` job red until the array-bracket baseline is fixed.
- `gh pr merge` works server-side but its local post-merge branch switch can error on the
  config.lock issue — harmless; `git fetch && git checkout main && git pull` manually.

## Deploy (Render)

- Merging to `main` **auto-deploys** to Render (signalfire.live). No manual step, no gate.
- `render.yaml` startCommand runs **`rails db:prepare` on every boot**:
  - Migrations run **unattended in production** on deploy — see the `safe-changes` skill before
    writing any migration.
  - `db:seed` no longer runs on deploy (removed 2026-07: seeds are demo data with well-known
    passwords) and `db/seeds.rb` no-ops in production. Keep it idempotent for local use.
  - `db:prepare` (not `db:migrate`) is deliberate: Solid Cache/Cable schemas load from schema
    files, not migrations. Don't "simplify" it to db:migrate.
- Health check path: `/up` (Rails liveness endpoint). Verify a deploy by curling the production site and checking the
  feature landed; there is no staging environment.

## Dev servers & email

- `bin/dev` runs all three Procfile.dev processes: `web` (rails server), `css` (tailwind watch),
  `worker` (`bin/jobs`, Solid Queue).
- Dev email opens in the browser via letter_opener_web: http://localhost:3000/letter_opener

## Troubleshooting

See [references/troubleshooting.md](references/troubleshooting.md) for symptom → fix mapping
(connection refused on 5432, log/test.log unwritable, minitest optparse crash, mise not found).
