---
description: List all active Claude Code sessions and their states
allowed-tools: Bash
---

Run the following command to list all active Claude Code sessions:

```bash
"${CLAUDE_PLUGIN_ROOT}/dist/bin/claude-watchdog" list
```

Present the results to the user. Each line shows `project-name: state` where state is one of:
- **waiting (input)** - Session is idle, waiting for user input
- **waiting (question)** - Claude asked a question, waiting for answer
- **waiting (approval)** - Claude is in plan mode, waiting for approval
- **running** - Claude is actively working

If there are no sessions, tell the user that no active sessions were found.

For JSON output, add `--format json` to the command.
