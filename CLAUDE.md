# claude-watchdog

Claude Code plugin that monitors multiple session states via hooks and SQLite. Written in MoonBit (native backend).

## Key Resources

- Architecture: [docs/architecture.md](docs/architecture.md)
- Hook config: [hooks/hooks.json](hooks/hooks.json)
- CLI entry point: [cmd/main/main.mbt](cmd/main/main.mbt)
- Library packages: [lib/](lib/)

## Guidelines

- When adding a new feature, update the relevant documentation (README.md, docs/architecture.md)

## Commands

```bash
# Build
moon build --target native
cp _build/native/debug/build/cmd/main/main.exe dist/claude-watchdog

# Test
moon test --target native

# Run CLI (dev)
moon run cmd/main -- <command>

# Format
moon fmt

# Type check
moon check --target native
```
