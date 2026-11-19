# AI data sources

Where SuperDock gets AI usage limits and agent status. Everything was checked against real files on macOS 26 on 2026-11-19 (Claude Code 2.1.311, Codex CLI 0.159.2). Field names come from the files. No message content was read to write this.

**Rule:** SuperDock reads only status, timestamps, limit percentages and the project folder name. Lines that can contain prompts or code are skipped by checking each line's first bytes, so they are never decoded (see Codex below).

## Claude Code

### Agent status: `~/.claude/sessions/<pid>.json`

One small JSON file per running Claude Code process, rewritten whenever its state changes.

| Field | Type | Use |
|---|---|---|
| `pid` | number | Process id; a file whose process is gone is stale and ignored |
| `sessionId` | string | Row id |
| `cwd` | string | Last path component = project name |
| `status` | string | `busy`, `shell`, `idle`, `waiting` (enum found in the Claude Code binary) |
| `statusUpdatedAt` | number (ms since 1970) | When `status` last changed |
| `updatedAt` | number (ms) | Last write |
| `kind` | string | `interactive`, `bg`, `daemon`, `daemon-worker` |

Not read: `name` and `nameSource`. They can hold an auto-generated session title, which may be derived from the prompt.

Status mapping:

| `status` | Board |
|---|---|
| `busy`, `shell` | working (blue) |
| `waiting` | needs input (orange) |
| `idle`, changed < 10 min ago | done (green) |
| `idle`, older | idle (grey) |

### Usage limits: status line payload (opt-in bridge)

Session (5-hour) and weekly percentages are **not stored anywhere on disk**. Transcripts in `~/.claude/projects/*/*.jsonl` only carry `rate_limit_info` when a request is *rejected* for hitting a limit. They also carry per-message token counts, but turning those into a percentage would need Anthropic's plan limits, which aren't published.

Claude Code does pass the live numbers to the status line command on stdin:

```json
{ "rate_limits": {
    "five_hour": { "used_percentage": 42.5, "resets_at": 1795100000 },
    "seven_day": { "used_percentage": 7,    "resets_at": 1795500000 } } }
```

(`resets_at` is epoch seconds. `seven_day_sonnet` and `seven_day_opus` may also appear. Shape confirmed from the ccstatusline schema.)

**Bridge:** Settings → AI → *Connect Claude Code* points `statusLine.command` in `~/.claude/settings.json` at `~/Library/Application Support/SuperDock/claude-statusline.sh`. That script:
1. extracts **only** `rate_limits` with `/usr/bin/plutil -extract rate_limits json`, writing it to `claude-limits.json` next to the script;
2. pipes the unchanged payload into the user's original status line command, so their status line looks the same.

Disconnecting restores the original `statusLine` value. `settings.json` is backed up to `settings.json.superdock-backup` before each change. The numbers update whenever any Claude Code session redraws its status line (`refreshInterval`, 10 s here). When no session is running, the tile shows the last values and the time they were captured. Once a window's reset time has passed, that window shows as reset.

## Codex CLI

Files: `~/.codex/sessions/YYYY/MM/DD/rollout-<timestamp>-<uuid>.jsonl`. Each line starts with `{"timestamp":…,"ordinal":N,"type":"<type>","payload":{"type":"<event>"…`.

Line types seen: `session_meta`, `turn_context`, `event_msg`, `response_item`, `token_usage_record`, `world_state`. **`response_item` lines hold messages and tool calls (prompt and code text) and are never decoded.** The reader looks at a line's first 120 bytes and only decodes the line if it contains `"type":"event_msg"` (or, for the first line only, `"type":"session_meta"`).

### Limits: `event_msg` → `payload.type == "token_count"`

```text
payload.rate_limits.limit_id            "codex"
payload.rate_limits.plan_type           "free" | …
payload.rate_limits.primary.used_percent    number (0–100)
payload.rate_limits.primary.window_minutes  number
payload.rate_limits.primary.resets_at       number (epoch seconds)
payload.rate_limits.secondary.…             same shape, may be absent
```

On this machine (free plan) there is only `primary`, with `window_minutes = 43200` (30 days). Paid plans report a 5-hour (`300`) and a weekly (`10080`) window. Windows are therefore labelled by `window_minutes`, not by primary/secondary. The latest `token_count` in the most recently modified rollout file wins.

### Agent status: last `event_msg` in each recently modified rollout

| Last event (`payload.type`) | Board |
|---|---|
| `exec_approval_request`, `apply_patch_approval_request`, `request_permissions`, `request_user_input`, `elicitation_request` | needs input |
| `task_complete`, `turn_aborted` | done (< 10 min) → idle |
| anything else, file written < 2 min ago | working |
| anything else, older | idle |

Event names come from the Codex 0.159.2 binary. `task_started`, `task_complete` and `token_count` were seen in real files. **The approval events were not**: there was no approval in the sample, so it's unverified whether they're written to the rollout file. Project name comes from `session_meta.payload.cwd` (first line).

Sessions whose file hasn't changed for 30 minutes drop off the board. Codex has no live process registry like Claude's.

## Antigravity

Not installed on the dev machine (no `~/Library/Application Support/Antigravity`, `~/.gemini` or `~/.antigravity`). **Not implemented.** Ship as "experimental" only after its local state has been inspected on a machine that has it.

## Cursor

Only `~/.cursor/skills` exists on the dev machine; the Cursor app isn't installed. **Not implemented**, for the same reason.
