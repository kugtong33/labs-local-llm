# Tasks: Add Qwen3-Coder to Supported Models

**Input**: Design documents from `/specs/002-add-qwen3-coder/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓

**Tests**: No test tasks — none requested in the feature specification.

**Organization**: 2 user stories, 2 file changes, no dependencies between them.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2)

## Path Conventions

```text
models/registry.conf   # append one line
README.md              # add one row to the model table
```

---

## Phase 1: Setup

No setup required — this feature modifies two existing files with no new directories or dependencies.

---

## Phase 2: Foundational

No foundational phase required — changes are independent and additive.

---

## Phase 3: User Story 1 — Provision Qwen3-Coder Like Any Other Model (Priority: P1) 🎯 MVP

**Goal**: `./scripts/provision.sh -m qwen3-coder` works end-to-end.

**Independent Test**: Run `./scripts/provision.sh -m bad-model` — the error output must list `qwen3-coder` among supported models. On a machine with Ollama, run `./scripts/provision.sh -m qwen3-coder -M cpu` and verify the server starts.

### Implementation for User Story 1

- [x] T001 [US1] Append `qwen3-coder|qwen3-coder|6|12|stable` to `models/registry.conf` — verify with `ollama search qwen3-coder` that the Ollama ID is correct before committing; update the second field if the actual ID differs

---

## Phase 4: User Story 2 — Qwen3-Coder Listed as a Supported Option (Priority: P2)

**Goal**: Qwen3-Coder is discoverable in documentation and appears in the provision script's error output.

**Independent Test**: Run `./scripts/provision.sh -m invalid` and confirm `qwen3-coder` appears in the error message. Read `README.md` and confirm the model table contains a Qwen3-Coder row.

### Implementation for User Story 2

- [x] T002 [P] [US2] Add Qwen3-Coder row to the model comparison table in `README.md`: `` | `qwen3-coder` | ~6 GB | ~12 GB | Code-specialized; recommended for coding-focused tasks | ``

---

## Phase 5: Polish & Cross-Cutting Concerns

- [x] T003 [P] Verify `./scripts/provision.sh -m bad-model` error output now lists `qwen3-coder` alongside `deepseek-v3`, `glm-4`, and `minimax-m1`

---

## Dependencies & Execution Order

### Phase Dependencies

- T001 and T002 are independent — both modify different files and can be done in any order or in parallel
- T003 depends on T001 (registry must be updated for the error output to include `qwen3-coder`)

### User Story Dependencies

- **US1 (P1)**: No dependencies
- **US2 (P2)**: No dependencies on US1 — README update is independent of the registry change

### Parallel Opportunities

- T001 and T002 can run in parallel (different files)

---

## Parallel Example

```text
# Both can run simultaneously:
Task T001: Append qwen3-coder line to models/registry.conf
Task T002: Add Qwen3-Coder row to README.md model table
```

---

## Implementation Strategy

### MVP (US1 only — 1 task)

1. T001: Add registry entry → provision script immediately accepts `-m qwen3-coder`
2. Validate: run `./scripts/provision.sh -m bad-model` and confirm `qwen3-coder` is listed

### Full Delivery (2 tasks + polish)

1. T001 + T002 in parallel → both files updated
2. T003: Verify error output

---

## Notes

- [P] tasks = different files, no dependencies on each other
- Total: 3 tasks across 2 user stories
- **Important**: Verify the Ollama ID (`qwen3-coder`) is correct before merging T001 — see research.md
- No script changes, no Docker changes, no new files
