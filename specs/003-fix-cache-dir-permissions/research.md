# Research: Fix Model Cache Directory Permission Error

**Feature**: `003-fix-cache-dir-permissions`
**Date**: 2026-03-25
**Status**: Complete

---

## Decision 1: New Default Cache Path

**Decision**: Use `${HOME}/.local/share/llm-models` as the new default value for `MODEL_CACHE_DIR` in `provision.sh`.

**Rationale**: `$HOME/.local/share/` is the XDG Base Directory standard location for application data on Linux. It is always user-writable without sudo, predictable across distributions, and co-locates the cache with other user application data. This avoids the system-level `/opt/` tree, which is conventionally owned by root.

**Alternatives considered**:
- `~/llm-models` (home root): Simpler but pollutes the home directory root with a project-specific folder.
- `$HOME/.cache/llm-models`: More idiomatic for transient/removable data (XDG cache dir), but model weights are large and valuable — users would not expect a cache cleaner to delete them.
- `$XDG_DATA_HOME/llm-models`: Fully XDG-compliant but introduces a variable that may not be set on all systems; `$HOME/.local/share` is the defined default for unset `$XDG_DATA_HOME`.

---

## Decision 2: Shell Variable Expansion in docker-compose.yml

**Decision**: Remove the hardcoded fallback from `docker-compose.yml`'s volume `device` field. Change `${MODEL_CACHE_DIR:-/opt/llm-models}` to `${MODEL_CACHE_DIR}` (no fallback), and rely on `provision.sh` always exporting `MODEL_CACHE_DIR` before invoking Docker Compose.

**Rationale**: Docker Compose variable substitution does not expand shell variables like `$HOME` or `~`. If a new default like `$HOME/.local/share/llm-models` were embedded as a fallback in `docker-compose.yml`, it would be treated as a literal string (not expanded), causing Docker to attempt to create/bind-mount a path literally named `$HOME/.local/share/llm-models`. Since `provision.sh` always resolves and exports `MODEL_CACHE_DIR` before calling `docker compose` (line 197), the docker-compose.yml fallback is dead code. Removing it makes the dependency explicit.

**Alternatives considered**:
- Keep the `/opt/llm-models` fallback in docker-compose.yml: Would preserve backward compat for direct `docker compose` usage, but contradicts the fix goal.
- Expand via `.env` file: Possible but requires users who run docker compose directly to always have `.env` populated with an absolute path — still no `$HOME` expansion.

---

## Decision 3: .env.example Representation

**Decision**: Update `.env.example` to show the new user-writable default as a commented-out example with an absolute placeholder path (`~/.local/share/llm-models`), and add a note that `provision.sh` sets this automatically, so the variable only needs to be set for custom overrides.

**Rationale**: Docker Compose reads `.env` for variable substitution but does not expand shell variables (`$HOME`, `~`). Showing `~/.local/share/llm-models` as a commented-out example communicates the intended default without implying it is shell-expanded by Docker Compose. Users who want a custom path should provide a full absolute path.

**Alternatives considered**:
- Show an empty default (`MODEL_CACHE_DIR=`): Confusing — implies no caching.
- Hardcode `/home/username/...`: Not portable across users.

---

## Decision 4: Files to Modify

**Decision**: Four files require changes — no new files.

| File | Change |
|------|--------|
| `scripts/provision.sh` | Line 166: change default from `/opt/llm-models` to `${HOME}/.local/share/llm-models` |
| `.env.example` | Update `MODEL_CACHE_DIR` entry to document new default; note that provision.sh sets it automatically |
| `docker-compose.yml` | Remove hardcoded `/opt/llm-models` fallback from volume `device` field; update comment |
| `README.md` | Fix Quick Start comment (line 43) and MiniMax-M1 section (lines 97–98) that reference old `/opt/llm-models` path |

No script logic changes are needed beyond the one-line default change in `provision.sh`. The existing error message (FR-003) already provides a clear remediation step.

---

## Unresolved Items

None. The root cause is a single hardcoded default. All decisions are confirmed by code inspection.
