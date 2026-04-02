# Architecture

## System Overview

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│  Claude Code     │     │   SQLite DB  │     │      CLI        │
│  (Hook events)   │────▶│  (raw events)│────▶│  (interpreted   │
│                  │     │              │     │   states)       │
└─────────────────┘     └──────────────┘     └─────────────────┘
                              │
                              ▼
                        ┌─────────────┐
                        │ User Hooks  │
                        │ (config.toml│
                        │  commands)  │
                        └─────────────┘
```

The system has four layers:

1. **Hooks** — Capture Claude Code lifecycle events and write raw data to the database
2. **Database** — Store raw event records per session
3. **CLI** — Read sessions, interpret states, and display results
4. **User Hooks** — Execute user-defined shell commands on events or state changes

## Build & Distribution

The project is written in **MoonBit** targeting the **native backend** (MoonBit → C → gcc/clang). SQLite is provided by the `moonbit-community/sqlite3` package which vendors SQLite 3.49.1 as an amalgamation source.

```
moon build --target native  →  _build/native/debug/build/cmd/main/main.exe
cp ... dist/claude-watchdog →  dist/claude-watchdog (native binary)
```

Distribution is via **npm**. The `bin` field in `package.json` points to `dist/claude-watchdog`.

## Data Flow

```
Claude Code emits event
  → hooks/hooks.json routes to `dist/claude-watchdog hook <event>`
    → cmd/main/main.mbt dispatches to hook command
      → lib/commands/hook.mbt reads stdin JSON, calls db
        → lib/db/db.mbt upserts raw event into SQLite
          → lib/config/config.mbt loads user config (if exists)
            → lib/userhooks/userhooks.mbt fires matching user-defined hooks

User runs CLI (or slash command)
  → dist/claude-watchdog <command>
    → cmd/main/main.mbt dispatches to command handler
      → lib/db/db.mbt reads sessions from SQLite
        → lib/interpret/interpret.mbt maps raw event to display state
          → output to stdout
```

### Event-to-CLI mapping

| Step | Component | File |
|------|-----------|------|
| Event received | Hook subcommand | `lib/commands/hook.mbt` |
| Data persisted | Database layer | `lib/db/db.mbt` |
| State interpreted | Interpretation | `lib/interpret/interpret.mbt` |
| Output displayed | CLI commands | `lib/commands/*.mbt` |

## Late Interpretation

Raw events are stored in the database as-is. State interpretation happens at
display time, not at write time.

**Why this design:**

- Adding new interpretations or changing state logic requires no data migration
- The database serves as an accurate event log
- Different consumers (CLI text, JSON, summary) can interpret the same data differently

## Database Schema

Location: `~/.claude/claude-watchdog.db` (SQLite, WAL mode)

```sql
CREATE TABLE sessions (
  session_id    TEXT PRIMARY KEY,
  cwd           TEXT NOT NULL,
  event         TEXT NOT NULL,
  tool_name     TEXT,
  session_name  TEXT,
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
| `session_name` | User-provided session name, NULL if not set |
| `created_at` | Unix timestamp of session creation (immutable after INSERT) |
| `updated_at` | Unix timestamp of last update |
| `state_changed_at` | Unix timestamp of last state change |
| `pane_id` | Terminal pane identifier (e.g., `%0` for tmux, `3` for WezTerm) |
| `pane_terminal` | Terminal type (e.g., `tmux`, `wez`), NULL if not in a multiplexer |

Each session has exactly one row. New events overwrite the previous row via UPSERT.

### NULL Handling

The `moonbit-community/sqlite3` package does not expose a NULL binding/reading API. The MoonBit implementation uses:

- **Write**: `NULLIF(?, '')` — bind empty string `""`, SQL converts to NULL
- **Read**: `COALESCE(column, '')` — NULL becomes empty string
- **MoonBit side**: `String` fields with `""` representing absent values
- **JSON output**: Custom serializer emits `null` for `""` fields

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

All hooks go through `dist/claude-watchdog hook <event>`. The `hook` subcommand
reads stdin JSON, extracts `session_id` and `cwd`, and calls `upsert_session`/
`delete_session` directly.

Errors are silently caught to never block Claude Code.

## User-Defined Hooks

Defined in `lib/config/` and `lib/userhooks/`. Users can configure shell commands
to run when events occur or session states change.

### Config File

Location (XDG Base Directory):
- `$XDG_CONFIG_HOME/claude-watchdog/config.toml`
- Fallback: `~/.config/claude-watchdog/config.toml`

Format: TOML with `[[hooks]]` array entries. Each entry has:
- `on_event` — Fire on a specific hook event (e.g., `"Stop"`, `"SessionStart"`)
- `on_state_change` — Fire on state transitions, with optional `from`/`to` filters
- `command` — Shell command to execute

`on_event` and `on_state_change` are mutually exclusive per entry.
State-change hooks only fire when previous state differs from new state.

### Environment Variables

Commands receive context via `MONITOR_`-prefixed environment variables:

| Variable | Description |
|----------|-------------|
| `MONITOR_SESSION_ID` | Session ID |
| `MONITOR_CWD` | Working directory |
| `MONITOR_EVENT` | Hook event name |
| `MONITOR_TOOL_NAME` | Tool name (PreToolUse only, empty otherwise) |
| `MONITOR_SESSION_NAME` | Session name (if set) |
| `MONITOR_STATE` | Current interpreted state (empty for SessionEnd) |
| `MONITOR_PREV_STATE` | Previous state (empty for new sessions) |
| `MONITOR_PANE_ID` | Terminal pane ID (if available) |
| `MONITOR_PANE_TERMINAL` | Terminal type (if available) |

### Execution

Hook commands are spawned as detached background processes via `fork()` + `exec()`.
The child process sets environment variables via `setenv()`, redirects stdio to
`/dev/null`, and creates a new session with `setsid()`. The parent process does not
wait for the child. All errors are silently caught to never interfere with Claude Code operation.

## Terminal Detection

Defined in `lib/terminal/terminal.mbt`. Detects the terminal multiplexer environment
by checking environment variables. First match wins (tmux has priority).

| Terminal | Env Variable | `terminal` | Example `pane_id` |
|----------|-------------|------------|-------------------|
| tmux | `TMUX_PANE` | `tmux` | `%0` |
| WezTerm | `WEZTERM_PANE` | `wez` | `3` |

## Reconcile (Stale Session Cleanup)

Defined in `lib/reconcile/reconcile.mbt`. Removes sessions that persist after Claude Code crashes
or is killed without sending `SessionEnd`.

### Strategy: Hybrid (Pane Check + TTL)

- **Sessions with `pane_id`**: Check if the terminal pane still exists via CLI. If the pane is gone, the session is stale.
- **Sessions without `pane_id`**: Fall back to TTL. If `updated_at` is older than 24 hours, the session is stale.
- **Pane check fails** (CLI not found, timeout): Skip that session (do not delete, do not fall back to TTL).

### Pane Existence Checks

| Terminal | Command | Parse |
|----------|---------|-------|
| tmux | `tmux list-panes -a -F '#{pane_id}'` | Set of lines |
| wez | `wezterm cli list --format json` | Set of `pane_id` from JSON |

Results are cached per terminal type within a single reconcile call, so each
terminal CLI runs at most once.

### Timing

- Auto-reconcile runs at the start of `list` (opt-out via `--no-reconcile`)
- Standalone `reconcile` command also available

### Stale Session Handling

For each stale session:
1. Capture `prev_state` via `interpret_state(session)`
2. Call `delete_session(session.session_id)`
3. Fire user hooks with `SessionEnd` context

## Session State Machine

Defined in `lib/interpret/interpret.mbt`. The interpretation maps raw events to display states:

```
SessionStart ──────────▶ waiting (input)
Stop ──────────────────▶ waiting (input)
UserPromptSubmit ──────▶ running
PreToolUse
  ├─ AskUserQuestion ──▶ waiting (question)
  └─ ExitPlanMode ─────▶ waiting (approval)
```

## C FFI Layer

Defined in `lib/ffi/`. MoonBit's native backend compiles to C, allowing direct
interop with C functions. The FFI layer provides system primitives not available
in MoonBit's standard library:

| Function | Purpose |
|----------|---------|
| `read_stdin` | Read all of stdin |
| `read_file` | Read entire file contents |
| `popen` | Run command, capture stdout |
| `spawn_detached` | Fire-and-forget background process |
| `isatty` | Check if fd is a terminal |
| `eprintln` | Write to stderr |
| `exit` | Exit process with code |
| `home_dir` | Get user home directory |
| `now_unix` | Current unix timestamp in seconds |

String conversion between MoonBit (UTF-16) and C (UTF-8) uses `@utf8.encode()`
and `@utf8.decode_lossy()` from the standard library.

## Directory Structure

```
claude-watchdog/
├── .claude-plugin/
│   ├── plugin.json          # Plugin manifest
│   └── marketplace.json     # Marketplace configuration (npm source)
├── commands/
│   └── monitor-list.md      # /monitor-list slash command
├── dist/
│   └── claude-watchdog      # Native binary (gitignored, built via moon build)
├── hooks/
│   └── hooks.json           # Hook event configuration
├── lib/
│   ├── ffi/                 # C FFI bindings (stub.c + ffi.mbt)
│   ├── types/               # HookEvent, SessionState, Session, PaneInfo
│   ├── db/                  # SQLite CRUD operations
│   ├── interpret/           # State interpretation + elapsed formatting
│   ├── terminal/            # Terminal multiplexer detection
│   ├── config/              # TOML config parsing + validation
│   ├── userhooks/           # User-defined hook matching + execution
│   ├── reconcile/           # Stale session cleanup
│   └── commands/            # CLI command handlers (hook, list, update, delete, reconcile)
├── cmd/
│   └── main/
│       └── main.mbt         # CLI entry point / dispatcher
├── moon.mod.json            # MoonBit module configuration
└── package.json             # npm distribution configuration
```
