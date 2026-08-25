# Agent Guidelines for tmux-rendez-vous

## Project Overview

Tmux TPM plugin written in bash. Provides utilities to manage tmux sessions.

**Requirements:** Tmux 3.6+, Bash 4.4+ (4.4 for `readarray -d`)

## External Dependencies

Required in user's environment:
- `sesh` - session management
- `lazy-tmux` - session persistence
- `fzf` - plugin pickers

## Build, Lint, and Test Commands

```bash
# Install and run pre-commit
pip install pre-commit
pre-commit install --hook-type pre-commit --hook-type commit-msg
pre-commit run --all-files
```

**No automated tests.** Test manually by loading the plugin in tmux:
```bash
tmux source-file ~/.tmux.conf
```

## Architecture

- `plugin.tmux` - main entry point (tmux-sourced), injects `bin/` into PATH
- `bin/` - executable scripts exported to tmux environment
- Uses `readarray -d` requiring Bash 4.4+ (not 3.0)

## Tmux Conventions

- Use `-gv` for global option get: `tmux show-options -gv '@option'`
- Use `-v` for value-only output
- Double quotes for format strings

## Knowledge Graph / Understand-Anything

This project uses Understand-Anything to maintain a knowledge graph of the codebase. The graph powers interactive exploration and is the source of truth for architecture, dependencies, and onboarding.

Use proactivly these commands in first place when you require better context on any task:

- `/understand` — Build or incrementally update the knowledge graph. Run before architectural changes or after significant refactors. Options: `--full`, `--auto-update`, `--review`, `--language <lang>`, `--exclude <patterns>`.
- `/understand-chat` — Ask questions about the codebase using the graph as context, e.g. “How does plugin initialization work?” or “Which modules depend on `tmux::plugin.sh`?”.
- `/understand-explain` — Deep-dive explanation of a specific file, function, or module with cross-references from the graph.
- `/understand-diff` — Analyze git diffs / PRs against the graph to understand affected components and risks.
- `/understand-domain` — Extract business domain knowledge and generate a domain flow graph.
