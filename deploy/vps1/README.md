# VPS1 deployment scripts

All scripts assume `CENTAURION_REPO=/root/Cortex` (set by cron; the default
`$HOME/Centaurion` is the pre-rename path).

| Script | Trigger | Purpose |
|---|---|---|
| `centaurion-dev-loop.sh` | cron `0 4,12,20 * * *` | Pull, run `tests/identify-next-priority.sh`, hand the first fixable failure to `claude -p`, commit, push, write `memory/state/dev-loop-status.json`, then run `health-check.sh`. |
| `health-check.sh` | called by the dev loop (no cron line needed) | Disk / memory / docker / claude auth / git snapshot to `memory/state/health-status.json`. |
| `sync-private.sh` | cron `0 21 * * *` | Private sync. |
| `weekly-review.sh` | cron `0 5 * * 1` | Weekly review. |
| `autoresearch.sh` | manual | Research loop. |

## Headless Claude auth (the durable fix for "OAuth session expired")

`claude login` in a terminal stores a browser OAuth session. Cron cannot refresh
it, so after a while every `claude -p` run fails instantly with
`Failed to authenticate: OAuth session expired and could not be refreshed`.
The dev loop now reports that as `status: "error"`, `error_reason: "auth_expired"`.

Fix it once with a long-lived token:

```bash
# 1. On your Mac (or on VPS1) — prints a sk-ant-oat01-... token for your Max subscription
claude setup-token

# 2. On VPS1, as root — store it where the dev loop sources it
mkdir -p /root/.config/centaurion && umask 077 && \
  printf 'CLAUDE_CODE_OAUTH_TOKEN=%s\n' '<paste token>' > /root/.config/centaurion/env && \
  chmod 600 /root/.config/centaurion/env

# 3. Verify
cd /root/Cortex && set -a && . /root/.config/centaurion/env && set +a && claude -p 'say ok' --max-turns 1
```

`centaurion-dev-loop.sh` sources `/root/.config/centaurion/env` (override with
`CENTAURION_ENV_FILE`) at startup and exports everything in it, so
`CLAUDE_CODE_OAUTH_TOKEN` reaches `claude -p`. The file is outside the repo and
must never be committed. `dev-loop-status.json` shows `auth_source:
oauth_token_env` once it is in effect.

## Reading `dev-loop-status.json`

| Field | Meaning |
|---|---|
| `status` | `progressing` / `all_passing` / `failing` / `error` |
| `error_reason` | `auth_expired`, `claude_missing`, `claude_exit_N`, `instant_exit` (< 60 s), `error_signature`, `git_pull_failed` |
| `claude_exit`, `claude_elapsed_seconds` | raw signal from the `claude -p` call |
| `claude_stderr_tail` | last 30 lines of claude output |
| `consecutive_zero_fix_runs` | runs in a row with `tests_fixed: 0`; the daily issue turns red at 3 |
| `auth_source` | `oauth_token_env` or `interactive_login` |

The status file is committed and pushed every run (message
`status: dev loop error (<reason>) <date>` on failures) so
`.github/workflows/daily-dev-loop.yml` can render it.

## Host-config tests (Phase 7 R31.x)

`tests/verify-production.sh` R31.1–R31.4 check claude auth, the crontab, a
recent successful run and push rights. They can only be fixed on the host, so
the dev loop runs the picker with `CENTAURION_SKIP_HOST_TESTS=1` and never hands
them to Claude. Run `bash tests/verify-production.sh` on VPS1 to see them.
