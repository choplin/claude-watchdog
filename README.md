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

```bash
claude /install-plugin /path/to/claude-code-monitor
```

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

## 🚀 CLI Usage

### `list` — Show all sessions

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

### `summary` — One-line summary

```bash
claude-code-monitor summary
```

```
2/3
```

Outputs `waiting/total` — useful for status lines (e.g. tmux).

### `update` — Register/update a session (internal)

Used internally by hooks. Not intended for direct use.

```bash
claude-code-monitor update \
  --session-id <id> \
  --cwd <path> \
  --event <event> \
  [--tool-name <name>] \
  [--tmux-pane <pane>]
```

### `delete` — Delete a session (internal)

Used internally by hooks. Not intended for direct use.

```bash
claude-code-monitor delete --session-id <id>
```

## 🗄️ Data Storage

Session data is stored in `~/.claude/claude-code-monitor.db` (SQLite, WAL mode).
