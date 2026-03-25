# Implementation Plan: Fix Model Cache Directory Permission Error

**Branch**: `003-fix-cache-dir-permissions` | **Date**: 2026-03-25 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/003-fix-cache-dir-permissions/spec.md`

## Summary

Change the default value of `MODEL_CACHE_DIR` in `provision.sh` from `/opt/llm-models` (requires root to create) to `${HOME}/.local/share/llm-models` (user-writable, no sudo required). Update the matching defaults and documentation in `.env.example`, `docker-compose.yml`, and `README.md`.

## Technical Context

**Language/Version**: Bash (POSIX-compatible shell scripts, `set -euo pipefail`)
**Primary Dependencies**: Docker Engine 24+, Docker Compose v2, Ollama (docker image `ollama/ollama:latest`)
**Storage**: Local bind-mount via Docker named volume (`model-cache`); path controlled by `MODEL_CACHE_DIR`
**Testing**: Manual validation (`./scripts/provision.sh -m glm-4` succeeds without sudo on a fresh machine)
**Target Platform**: Linux (Ubuntu/Debian primary)
**Project Type**: DevOps tooling / shell scripts
**Performance Goals**: N/A (configuration change only)
**Constraints**: Docker Compose does not expand `$HOME` or `~` in variable substitution; `provision.sh` must resolve the path in bash before passing to Docker Compose
**Scale/Scope**: 4 files, 1 functional line change + documentation updates

## Constitution Check

The constitution template is unfilled — no project-specific gates defined. No violations applicable.

## Project Structure

### Documentation (this feature)

```text
specs/003-fix-cache-dir-permissions/
├── plan.md              # This file
├── research.md          # Phase 0 output (complete)
├── tasks.md             # Phase 2 output (/speckit.tasks command)
└── checklists/
    └── requirements.md  # Spec quality checklist (all passing)
```

### Source Code (repository root)

```text
scripts/
└── provision.sh         # Line 166: change MODEL_CACHE_DIR default

.env.example             # Update MODEL_CACHE_DIR entry + comment

docker-compose.yml       # Remove /opt/llm-models fallback from volume device field

README.md                # Fix Quick Start comment and MiniMax-M1 section references
```

**Structure Decision**: No new files or directories. All changes are in-place edits to existing files. The fix is a single default value change in `provision.sh` (the authoritative source for the default); the other three files are documentation/config files that reference the old default path.

## Complexity Tracking

No constitution violations. No complexity justification needed.

## Implementation Details

### 1. `scripts/provision.sh` — line 166

**Before**:
```bash
MODEL_CACHE_DIR="${MODEL_CACHE_DIR:-/opt/llm-models}"
```

**After**:
```bash
MODEL_CACHE_DIR="${MODEL_CACHE_DIR:-${HOME}/.local/share/llm-models}"
```

This is the only functional change. `$HOME` is always set in interactive and non-interactive login shells; Docker Compose receives the fully-resolved absolute path via the already-present `export MODEL_CACHE_DIR` on line 197.

---

### 2. `.env.example` — MODEL_CACHE_DIR block

Update the comment and value to document the new user-writable default. Note that `provision.sh` sets the default automatically; this variable only needs to be set for custom overrides. Shell variables (`$HOME`, `~`) are not expanded by Docker Compose.

**Before**:
```
MODEL_CACHE_DIR=/opt/llm-models
```

**After**:
```
# Default: ~/.local/share/llm-models (set automatically by provision.sh — no need to configure)
# To use a custom path, set an absolute path here. Shell variables like $HOME are not expanded by
# Docker Compose; provision.sh handles expansion for you if you run the server via scripts.
# Example: MODEL_CACHE_DIR=/data/llm-models
#MODEL_CACHE_DIR=~/.local/share/llm-models
```

---

### 3. `docker-compose.yml` — volumes block

Remove the `/opt/llm-models` hardcoded fallback. `provision.sh` always exports `MODEL_CACHE_DIR` before invoking Docker Compose, so the fallback is dead code.

**Before**:
```yaml
  model-cache:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: "${MODEL_CACHE_DIR:-/opt/llm-models}"
```

**After**:
```yaml
  model-cache:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: "${MODEL_CACHE_DIR}"
```

Update the comment above the volumes block to reflect the new default.

---

### 4. `README.md` — two locations

**Quick Start section** (line 43):
- Before: `# Edit .env to change MODEL_CACHE_DIR if /opt/llm-models is not writable`
- After: Remove this line (models are now stored in a user-writable default; no manual config needed for most users)

**MiniMax-M1 section** (lines 97–98):
- Before: references `/opt/llm-models` as the copy destination
- After: reference `~/.local/share/llm-models` (matching new default) with a note to use `$MODEL_CACHE_DIR` if overridden

Also update the `MODEL_CACHE_DIR` reference in `clean.sh --purge-models` documentation if applicable.
