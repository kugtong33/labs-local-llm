# Tasks: Fix Model Cache Directory Permission Error

**Input**: Design documents from `/specs/003-fix-cache-dir-permissions/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓

**Tests**: Not requested — no test tasks included.

**Organization**: Tasks grouped by user story. All tasks are independent file edits with no shared state.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2)

---

## Phase 1: User Story 1 — Provision Works Out of the Box Without Sudo (Priority: P1) 🎯 MVP

**Goal**: Change the default `MODEL_CACHE_DIR` from `/opt/llm-models` (requires root) to `${HOME}/.local/share/llm-models` (user-writable), and update the matching default in `.env.example` and `docker-compose.yml`.

**Independent Test**: On a machine where `/opt/llm-models` does not exist and the user is not root, run `./scripts/provision.sh -m glm-4` — must succeed without any sudo commands.

### Implementation for User Story 1

- [x] T001 [US1] Change `MODEL_CACHE_DIR` default from `/opt/llm-models` to `${HOME}/.local/share/llm-models` in `scripts/provision.sh` (line 166)
- [x] T002 [P] [US1] Update `MODEL_CACHE_DIR` entry in `.env.example` to document the user-writable default and note that provision.sh sets it automatically
- [x] T003 [P] [US1] Remove hardcoded `/opt/llm-models` fallback from `model-cache` volume `device` field in `docker-compose.yml`

**Checkpoint**: User Story 1 complete — `./scripts/provision.sh -m glm-4` succeeds without sudo on a fresh machine.

---

## Phase 2: User Story 2 — Default Cache Location Is Documented and Predictable (Priority: P2)

**Goal**: Update `README.md` to reflect the new default cache location wherever the old `/opt/llm-models` path appears.

**Independent Test**: Read `README.md` — both the Quick Start section and the MiniMax-M1 section must reference `~/.local/share/llm-models` (not `/opt/llm-models`).

### Implementation for User Story 2

- [x] T004 [US2] Update `README.md`: remove stale Quick Start comment about `/opt/llm-models` not being writable and update MiniMax-M1 copy example to use `~/.local/share/llm-models`

**Checkpoint**: User Stories 1 and 2 complete — documentation matches the new default.

---

## Dependencies & Execution Order

### Phase Dependencies

- **User Story 1 (Phase 1)**: No dependencies — can start immediately
- **User Story 2 (Phase 2)**: No dependencies on US1 — can be done in parallel

### User Story Dependencies

- **US1**: Independent — no prerequisites
- **US2**: Independent — no prerequisites; can run in parallel with US1

### Within Each User Story

- T001 is the core functional change; T002 and T003 are independent config/doc updates that can run in parallel with T001
- T004 is a standalone documentation task

### Parallel Opportunities

All four tasks touch different files with no shared state:

```
T001  scripts/provision.sh   │
T002  .env.example            │ All can run in parallel
T003  docker-compose.yml      │
T004  README.md               │
```

---

## Parallel Example: All Tasks

```bash
# All four tasks can be dispatched simultaneously:
Task T001: "Change MODEL_CACHE_DIR default in scripts/provision.sh line 166"
Task T002: "Update MODEL_CACHE_DIR entry in .env.example"
Task T003: "Remove /opt/llm-models fallback from docker-compose.yml volume device field"
Task T004: "Fix /opt/llm-models references in README.md"
```

---

## Implementation Strategy

### MVP (User Story 1 Only)

1. Complete T001, T002, T003 (can run in parallel)
2. **VALIDATE**: Run `./scripts/provision.sh -m glm-4` on a fresh machine without sudo
3. Confirm `mkdir: cannot create directory '/opt/llm-models': Permission denied` no longer occurs

### Full Delivery

1. MVP complete (T001–T003)
2. Add T004 (README documentation)
3. Both user stories complete

---

## Notes

- No new files created — all changes are in-place edits
- No setup or foundational phase needed — this is a pure default-value fix
- `shellcheck` must pass on `scripts/provision.sh` after T001
- The docker-compose.yml `device:` field does not expand `$HOME`; provision.sh always exports the resolved absolute path before calling `docker compose`, so removing the fallback is safe
