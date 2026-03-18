# 🖥️ claude-code-monitor

> Monitor multiple Claude Code session states from a single place.

A Claude Code plugin that monitors the state of multiple Claude Code sessions in real time.

## ✨ Overview

```
Hook (auto-collect)  →  SQLite DB  →  CLI (display)
```

- **Hooks** automatically capture Claude Code lifecycle events
- **SQLite** stores raw event data (Late Interpretation pattern)
- **CLI** lists and summarizes all session states

## 📦 Installation

### From Marketplace (npm)

```bash
/plugin marketplace add owner/claude-code-monitor
/plugin install claude-code-monitor@claude-code-monitor
```

### From Local Path

```bash
/plugin marketplace add ./path/to/claude-code-monitor
/plugin install claude-code-monitor@claude-code-monitor
```

### Prerequisites

Node.js is required (provided by Claude Code's runtime).

## 🔍 How It Works

### Event Collection

The plugin hooks automatically collect the following events:

| Event | Description |
|-------|-------------|
| `SessionStart` | Session started |
| `SessionEnd` | Session ended (record deleted) |
| `UserPromptSubmit` | User sent a prompt |
| `PreToolUse(AskUserQuestion)` | Claude is asking the user a question |
| `PreToolUse(ExitPlanMode)` | Claude is requesting plan approval |
| `Stop` | Claude finished processing |

### Late Interpretation

Raw events are stored in the database and interpreted into 4 states at display time:

| State | Meaning | Source Events |
|-------|---------|---------------|
| `waiting (input)` | Waiting for user input | `SessionStart`, `Stop` |
| `waiting (question)` | Waiting for question answer | `PreToolUse(AskUserQuestion)` |
| `waiting (approval)` | Waiting for plan approval | `PreToolUse(ExitPlanMode)` |
| `running` | Processing | `UserPromptSubmit` |

## 🚀 Usage

### Slash Commands (in Claude Code)

| Command | Description |
|---------|-------------|
| `/monitor-list` | Show all active sessions and their states |

### CLI

#### `list` — Show all sessions

```bash
claude-code-monitor list
```

```
my-project: waiting (input)
api-server: running
web-app: waiting (question)
```

JSON format:

```bash
claude-code-monitor list --format json
```

Skip auto-reconcile (stale session cleanup):

```bash
claude-code-monitor list --no-reconcile
```

#### `reconcile` — Remove stale sessions

Cleans up ghost sessions from crashed or killed Claude Code instances.

- Sessions with a terminal pane: checks if the pane still exists (tmux/WezTerm)
- Sessions without a pane: removed if not updated in the last 24 hours

```bash
claude-code-monitor reconcile
claude-code-monitor reconcile --format json
```

Auto-reconcile also runs at the start of `list` (opt-out via `--no-reconcile`).

#### `update` — Register/update a session (internal)

Used internally by hooks. Not intended for direct use.

```bash
claude-code-monitor update \
  --session-id <id> \
  --cwd <path> \
  --event <event> \
  [--tool-name <name>] \
  [--pane-id <pane>] \
  [--pane-terminal <terminal>]
```

#### `delete` — Delete a session (internal)

Used internally by hooks. Not intended for direct use.

```bash
claude-code-monitor delete --session-id <id>
```

## 🔔 User-Defined Hooks

Execute custom shell commands when events occur or session states change — desktop notifications, sounds, logging, etc.

### Configuration

Create a config file at `~/.config/claude-code-monitor/config.toml` (or `$XDG_CONFIG_HOME/claude-code-monitor/config.toml`):

```toml
# Fire on a specific event
[[hooks]]
on_event = "Stop"
command = "notify-send 'Claude stopped'"

[[hooks]]
on_event = "SessionStart"
command = "echo $MONITOR_SESSION_ID >> ~/claude-sessions.log"

# Fire on state changes
[[hooks]]
on_state_change = { to = "waiting_input" }
command = "terminal-notifier -message 'Waiting for input'"

[[hooks]]
on_state_change = { from = "running", to = "waiting_question" }
command = "play-sound ~/alert.wav"
```

### Trigger Types

| Type | Description |
|------|-------------|
| `on_event` | Fire on a specific hook event (`SessionStart`, `SessionEnd`, `UserPromptSubmit`, `PreToolUse`, `Stop`) |
| `on_state_change` | Fire on state transitions. `from`/`to` are optional (omitted = wildcard). Only fires when state actually changes. |

`on_event` and `on_state_change` are mutually exclusive per hook entry.

### Environment Variables

Commands receive context via environment variables:

| Variable | Description |
|----------|-------------|
| `MONITOR_SESSION_ID` | Session ID |
| `MONITOR_CWD` | Working directory |
| `MONITOR_EVENT` | Hook event name |
| `MONITOR_TOOL_NAME` | Tool name (PreToolUse only) |
| `MONITOR_STATE` | Current interpreted state |
| `MONITOR_PREV_STATE` | Previous state |
| `MONITOR_PANE_ID` | Terminal pane ID |
| `MONITOR_PANE_TERMINAL` | Terminal type |

## 🗄️ Data Storage

Session data is stored in `~/.claude/claude-code-monitor.db` (SQLite, WAL mode).
