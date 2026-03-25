# Tasks: Update OpenCode Example Configuration

**Input**: Design documents from `/specs/004-update-opencode-config/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/opencode-config.md

**Organization**: Tasks grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2)

## Path Conventions

Files changed live directly in the repository root — no `src/` tree involved (config/docs update only).

---

## Phase 1: Setup

**Purpose**: Remove the outdated file so the replacement is unambiguous.

- [x] T001 Delete `examples/opencode/config.toml` (superseded by config.json in Phase 3)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: No shared infrastructure required for this docs-only change. Phase skipped.

**⚠️ CRITICAL**: Phase 3 (US1) can begin immediately after T001.

---

## Phase 3: User Story 1 — Configure OpenCode with a Local Model (Priority: P1) 🎯 MVP

**Goal**: Provide a copy-ready `config.json` that connects OpenCode to a running Ollama server with qwen3-coder as the active model — zero edits required beyond provisioning the model.

**Independent Test**: Run `./scripts/provision.sh -m qwen3-coder`, copy `examples/opencode/config.json` to `~/.config/opencode/config.json`, open OpenCode, confirm the model connects and responds.

### Implementation for User Story 1

- [x] T002 [US1] Create `examples/opencode/config.json` with `$schema`, ollama provider (`npm: @ai-sdk/openai-compatible`, `baseURL: http://localhost:11434/v1`), and qwen3-coder model entry (`name: qwen3-coder:latest`)
- [x] T003 [US1] Add header comment block to `examples/opencode/config.json` instructing users to: (1) start the server first with `provision.sh`, (2) copy the file to `~/.config/opencode/config.json`, (3) verify the model id via `curl http://localhost:11434/v1/models`

**Checkpoint**: `examples/opencode/config.json` is present, valid JSON, and passes schema contract from `specs/004-update-opencode-config/contracts/opencode-config.md`. US1 is fully functional.

---

## Phase 4: User Story 2 — Switch Between Supported Models (Priority: P2)

**Goal**: Make the model-switching pattern obvious in the example config so developers can adapt it to glm-4 or deepseek-v3 without guessing the format.

**Independent Test**: Open `examples/opencode/config.json`, uncomment the glm-4 entry, run `./scripts/provision.sh -m glm-4`, copy config, verify OpenCode uses glm4:latest.

### Implementation for User Story 2

- [x] T004 [US2] Add commented-out model entries for `glm4:latest` and `deepseek-v3:latest` inside the ollama `models` block in `examples/opencode/config.json`, with inline comments indicating which `provision.sh -m` flag corresponds to each

**Checkpoint**: The config file contains all three stable models. Switching models requires only uncommenting one entry and commenting out another.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Keep project documentation consistent with the new file.

- [x] T005 [P] Update `CLAUDE.md` — change the file path reference in the examples table from `examples/opencode/config.toml` to `examples/opencode/config.json` and update the format description if present
- [x] T006 [P] Validate `examples/opencode/config.json` is valid JSON (e.g., `python3 -m json.tool examples/opencode/config.json` or `jq . examples/opencode/config.json`)
- [ ] T007 Run quickstart validation from `specs/004-update-opencode-config/quickstart.md` — provision qwen3-coder, copy config, confirm OpenCode connects

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **User Story 1 (Phase 3)**: Depends on T001 (old file removed)
- **User Story 2 (Phase 4)**: Depends on T002–T003 (US1 complete)
- **Polish (Phase 5)**: Depends on T004 (US2 complete); T005 and T006 can run in parallel

### User Story Dependencies

- **User Story 1 (P1)**: After T001 — no other dependencies
- **User Story 2 (P2)**: After US1 complete (extends same file)

### Within Each User Story

- US1: T002 → T003 (comment block added after config structure is final)
- US2: T004 (single task, depends on US1)

### Parallel Opportunities

- T005 and T006 (Polish) can run in parallel once T004 is done
- No within-story parallelism needed — all tasks touch the same file

---

## Parallel Example: Polish Phase

```bash
# Run T005 and T006 simultaneously (different concerns, same file is read-only for T006):
Task T005: Update CLAUDE.md reference
Task T006: Validate JSON syntax of examples/opencode/config.json
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. T001 — Remove old TOML file
2. T002 → T003 — Create and annotate config.json
3. **STOP and VALIDATE**: Copy config, provision qwen3-coder, confirm OpenCode connects
4. Ship if validated

### Incremental Delivery

1. T001 + T002 + T003 → config.json with qwen3-coder (MVP)
2. T004 → add multi-model entries (US2 complete)
3. T005 + T006 + T007 → docs consistent, JSON valid, quickstart verified

---

## Notes

- [P] tasks operate on different files — no conflicts
- JSON does not support comments natively; use a `//`-free workaround — add a `_comment` key or place guidance in a companion `README.md` if OpenCode's schema rejects comment keys
- Model ids must include the `:latest` tag (matches Ollama server output) — see `specs/004-update-opencode-config/data-model.md` for the full reference table
- Commit after T003 (US1 complete) as a standalone deliverable before continuing to US2
