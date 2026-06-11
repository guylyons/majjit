# AGENTS.md

## Project Overview

This project uses Jujutsu (`jj`) for version control.

## Required Tools

- Use `jj` instead of `git`.
- Use `rg` instead of `grep`.
- Use `fd` instead of `find`.
- Use `awk` for structured pattern extraction.
- Use `sed` for simple text replacement.
- Use `codegraph` as the primary navigation tool.
- Use `codegraph` before opening files whenever possible to reduce token usage.
- Prefer targeted `codegraph` queries over reading entire files.

## Workflow

- Inspect the existing structure before editing.
- Minimize context usage by reading only the files required for the task.
- Prefer the smallest change that solves the problem.
- Do not rewrite working code unless explicitly requested.
- Commit incrementally with `jj`.
- Write commit messages that are brief, exact, and factual.
- Do not batch unrelated changes into one change.
