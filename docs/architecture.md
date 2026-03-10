# Architecture

## System Overview

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│  Claude Code     │     │   SQLite DB  │     │      CLI        │
│  (Hook events)   │────▶│  (raw events)│────▶│  (interpreted   │
│                  │     │              │     │   states)       │
└─────────────────┘     └──────────────┘     └─────────────────┘
```

The system has three layers:

1. **Hooks** — Capture Claude Code lifecycle events and write raw data to the database
2. **Database** — Store raw event records per session
3. **CLI** — Read sessions, interpret states, and display results

## Entry Point & Auto-Build

All invocations (hooks and CLI) go through `bin/claude-code-monitor`, a shell script that:

1. Builds the compiled binary (`bin/.compiled`) if missing or source has changed
2. Executes the compiled binary

```
First run:  bin/claude-code-monitor → bun build --compile → exec bin/.compiled
Next runs:  bin/claude-code-monitor → exec bin/.compiled (fast, no bun needed)
Source changed: bin/claude-code-monitor → rebuild → exec bin/.compiled
```

## Data Flow

```
Claude Code emits event
  → hooks/hooks.json routes to bin/claude-code-monitor hook <event>
    → cli.ts `hook` subcommand reads stdin, calls db directly
      → src/db.ts upserts raw event into SQLite

User runs CLI (or slash command)
  → bin/claude-code-monitor <command>
    → cli.ts dispatches to command handler
      → src/db.ts reads sessions from SQLite
        → src/interpret.ts maps raw event to display state
          → output to stdout
```

### Event-to-CLI mapping

| Step | Component | File |
|------|-----------|------|
| Event received | Hook subcommand | `src/commands/hook.ts` |
| Data persisted | Database layer | `src/db.ts` |
| State interpreted | Interpretation | `src/interpret.ts` |
| Output displayed | CLI commands | `src/commands/*.ts` |

## Late Interpretation

Raw events are stored in the database as-is. State interpretation happens at
display time, not at write time.

**Why this design:**

- Adding new interpretations or changing state logic requires no data migration
- The database serves as an accurate event log
- Different consumers (CLI text, JSON, summary) can interpret the same data differently

## Database Schema

Location: `~/.claude/claude-code-monitor.db` (SQLite, WAL mode)

```sql
CREATE TABLE sessions (
  session_id    TEXT PRIMARY KEY,
  cwd           TEXT NOT NULL,
  event         TEXT NOT NULL,
  tool_name     TEXT,
  created_at    INTEGER NOT NULL,
  updated_at    INTEGER NOT NULL,
  state_changed_at INTEGER NOT NULL,
  pane_id       TEXT,
  pane_terminal TEXT
);
```

| Column | Description |
|--------|-------------|
| `session_id` | Claude Code session identifier (primary key) |
| `cwd` | Working directory of the session |
| `event` | Last hook event name |
| `tool_name` | Tool name for `PreToolUse` events, NULL otherwise |
| `created_at` | Unix timestamp of session creation (immutable after INSERT) |
| `updated_at` | Unix timestamp of last update |
| `state_changed_at` | Unix timestamp of last state change |
| `pane_id` | Terminal pane identifier (e.g., `%0` for tmux, `3` for WezTerm) |
| `pane_terminal` | Terminal type (e.g., `tmux`, `wez`), NULL if not in a multiplexer |

Each session has exactly one row. New events overwrite the previous row via UPSERT.

## Hook Events

Configured in `hooks/hooks.json`:

| Event | Matcher | Handler action |
|-------|---------|----------------|
| `SessionStart` | — | Upsert session |
| `SessionEnd` | — | Delete session |
| `UserPromptSubmit` | — | Upsert session |
| `PreToolUse` | `AskUserQuestion` | Upsert session with tool_name |
| `PreToolUse` | `ExitPlanMode` | Upsert session with tool_name |
| `Stop` | — | Upsert session |

All hooks go through `bin/claude-code-monitor hook <event>`. The `hook` subcommand
reads stdin JSON, extracts `session_id` and `cwd`, and calls `upsertSession`/
`deleteSession` directly (no subprocess spawning).

Errors are silently caught to never block Claude Code.

## Terminal Detection

Defined in `src/terminal.ts`. A pluggable detector system identifies the terminal
multiplexer environment. Each detector checks an environment variable and returns
a `PaneInfo` (terminal type + pane ID). First match wins.

| Terminal | Env Variable | `terminal` | Example `paneId` |
|----------|-------------|------------|-------------------|
| tmux | `TMUX_PANE` | `tmux` | `%0` |
| WezTerm | `WEZTERM_PANE` | `wez` | `3` |

To add a new terminal, append a detector function to the `detectors` array in
`src/terminal.ts`.

The PANE column in `list` output displays `terminal:paneId` (e.g., `tmux:%0`, `wez:3`)
or `-` when no multiplexer is detected.

## Session State Machine

Defined in `src/interpret.ts`. The interpretation maps raw events to display states:

```
SessionStart ──────────▶ waiting (input)
Stop ──────────────────▶ waiting (input)
UserPromptSubmit ──────▶ running
PreToolUse
  ├─ AskUserQuestion ──▶ waiting (question)
  └─ ExitPlanMode ─────▶ waiting (approval)
```

## Directory Structure

```
claude-code-monitor/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── bin/
│   ├── claude-code-monitor  # Shell script entry point (auto-builds on first use)
│   └── .compiled            # Compiled binary (gitignored, built locally)
├── commands/
│   └── monitor-list.md      # /monitor-list slash command
├── hooks/
│   └── hooks.json           # Hook event configuration
├── src/
│   ├── cli.ts               # CLI entry point
│   ├── db.ts                # Database operations
│   ├── interpret.ts         # State interpretation logic
│   ├── terminal.ts          # Terminal pane detection
│   ├── types.ts             # Type definitions
│   └── commands/
│       ├── delete.ts        # `delete` command
│       ├── hook.ts          # `hook` command (stdin-based, used by hooks)
│       ├── list.ts          # `list` command
│       └── update.ts        # `update` command
├── package.json
└── tsconfig.json
```
