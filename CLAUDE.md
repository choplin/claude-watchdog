# claude-watchdog

Claude Code plugin that monitors multiple session states via hooks and SQLite.

## Key Resources

- Architecture: [docs/architecture.md](docs/architecture.md)
- Hook config: [hooks/hooks.json](hooks/hooks.json)
- CLI entry point: [src/cli.ts](src/cli.ts)
- State interpretation: [src/interpret.ts](src/interpret.ts)
- User-defined hooks: [src/config.ts](src/config.ts), [src/user-hooks.ts](src/user-hooks.ts)

## Guidelines

- When adding a new feature, update the relevant documentation (README.md, docs/architecture.md)

## Commands

```bash
# Build
npm run build

# Type check
npm run typecheck

# Test
npm test

# Run CLI (dev)
npx tsx src/cli.ts <command>
```
