# claude-watchdog

Claude Code plugin that monitors multiple session states via hooks and SQLite. Written in MoonBit (native backend).

## Key Resources

- Architecture: [docs/architecture.md](docs/architecture.md)
- Hook config: [hooks/hooks.json](hooks/hooks.json)
- CLI entry point: [cmd/main/main.mbt](cmd/main/main.mbt)
- Library packages: [lib/](lib/)

## Guidelines

- When adding a new feature, update the relevant documentation (README.md, docs/architecture.md)
- Always use MoonBit skills when working with MoonBit code:
  - `moonbit:moonbit-lang` — Language reference and coding conventions
  - `moonbit:moonbit-agent-guide-dev` — Project workflow, testing, and `moon` CLI usage
  - `moonbit:moonbit-refactoring` — Idiomatic refactoring patterns
  - `moonbit:moonbit-c-binding` — C FFI bindings
  - `moonbit:moonbit-spec-test-development` — Spec-driven development
  - `moonbit:moonbit-extract-spec-test` — Extract specs and tests from existing code

## Commands

```bash
# Build
npm run build

# Test
npm test

# Run CLI (dev)
moon run cmd/main -- <command>

# Format
moon fmt

# Type check
moon check --target native
```
