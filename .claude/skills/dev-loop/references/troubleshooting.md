# Troubleshooting the local environment

Symptom → cause → fix. All verified in this WSL2 setup unless marked.

## `connection to server at "127.0.0.1", port 5432 failed: Connection refused`

Postgres container is down. Usually Docker Desktop itself isn't running on Windows.

1. Check: `docker info >/dev/null 2>&1 && echo OK || echo DOWN`
2. If `docker` is "not found in this WSL 2 distro": Docker Desktop is stopped or WSL
   integration is off. **Ask the user** to start Docker Desktop (Settings → Resources →
   WSL Integration must include this distro). This cannot be fixed from inside WSL.
3. Then: `docker compose up -d --wait`
4. Then: `eval "$(~/.local/bin/mise activate bash)" && RAILS_ENV=test bin/rails db:prepare`

## `Rails Error: Unable to access log file ... log/test.log`

Harmless-but-noisy /mnt/c permission artifact. Rails redirects logging to STDERR and continues.
If it blocks something: `rm -f log/test.log && touch log/test.log` — the existing file can be
root-owned, so a bare `touch` fails with Permission denied; remove it first. Don't chase chmod —
mode bits on /mnt/c often can't be changed and mostly don't matter.

## `bin/rails test` crashes inside minitest `process_args` / optparse

Observed once (2026-07-02) with minitest 6.0.4 when the database was down — the environment
failure cascaded into a confusing optparse backtrace. Fix the DB connection first (above),
then re-run before treating this as a real minitest/Rails incompatibility. If it persists with
the DB up, check whether a dependabot minitest bump (e.g. 6.0.6) is involved and pin/upgrade
deliberately.

## `mise: command not found` / wrong Ruby

Non-interactive Bash calls skip `~/.bashrc`. Always prefix:
`eval "$(~/.local/bin/mise activate bash)" && <command>`.
mise honors `.ruby-version` (3.4.7); idiomatic-version-file support was enabled at install time.

## `git config` fails with `error: could not lock config file .git/config`

Intermittent /mnt/c chmod limitation — observed June 2026, but `git config --local` writes
verified working again on 2026-07-02, and `.git/config` now has a valid `[user]` block. So:
try the normal path first; only if this error actually appears, fall back to per-command env
vars (`GIT_AUTHOR_NAME`, `GIT_AUTHOR_EMAIL`, `GIT_COMMITTER_NAME`, `GIT_COMMITTER_EMAIL`).
The same root cause historically made `gh pr merge`'s local post-merge checkout error — the
merge still happened server-side; recover with `git fetch && git checkout main && git pull`.

## Hundreds of "modified" files, empty diffs

CRLF line-ending churn from the Windows mount. Verify with `git diff` (shows `^M` or nothing).
Reset it (`git checkout -- <paths>`) rather than committing it. A historical stash of pure CRLF
noise existed once (`stash@{0}`, ~481 files, zero content) — if you find such a stash, it is safe
to drop after confirming `git stash show -p` contains only line-ending changes.

## Seeds ran again in production?

Expected: `render.yaml` startCommand runs `db:seed` on every deploy. If a seed change caused
duplicate rows in production, the seed wasn't idempotent — fix it with find-or-create patterns
(`find_or_create_by!`), never bare `create!`.
