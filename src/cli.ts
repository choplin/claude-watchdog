import { initDb } from "./db";
import { runUpdate } from "./commands/update";
import { runList } from "./commands/list";
import { runDelete } from "./commands/delete";
import { runHook } from "./commands/hook";
import { runReconcile } from "./commands/reconcile";

const HELP = `claude-code-monitor - Monitor multiple Claude Code session states

Usage:
  claude-code-monitor <command> [options]

Commands:
  update      Register or update a session
  list        List all sessions
  delete      Delete a session
  reconcile   Remove stale sessions (dead panes + TTL)
  hook        Handle hook events (internal, reads stdin)

Options:
  --help    Show this help message

Examples:
  claude-code-monitor update --session-id abc123 --cwd /path/to/project --state running
  claude-code-monitor list
  claude-code-monitor list --format json
  claude-code-monitor list --no-reconcile
  claude-code-monitor reconcile
  claude-code-monitor reconcile --format json
  claude-code-monitor delete --session-id abc123
`;

function printHelp(): void {
  console.log(HELP);
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const command = args[0];

  if (!command || command === "--help" || command === "-h") {
    printHelp();
    process.exit(0);
  }

  // hook subcommand handles its own initDb() call
  if (command === "hook") {
    await runHook(args.slice(1));
    return;
  }

  initDb();

  switch (command) {
    case "update":
      runUpdate(args.slice(1));
      break;
    case "list":
      runList(args.slice(1));
      break;
    case "delete":
      runDelete(args.slice(1));
      break;
    case "reconcile":
      runReconcile(args.slice(1));
      break;
    default:
      console.error(`Unknown command: ${command}`);
      printHelp();
      process.exit(1);
  }
}

main();
