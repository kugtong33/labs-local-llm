# Tasks: Curate Model Registry for Local Hardware

**Input**: Design documents from `/specs/006-curate-model-registry/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, quickstart.md ✓

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)

---

## Phase 1: Setup

**Purpose**: No project structure changes needed — this is a data-change feature using existing files.

- [x] T001 Read models/registry.conf, scripts/provision.sh, and models/minimax-m1.Modelfile to confirm current state before making changes

---

## Phase 3: User Story 1 — Remove Infeasible Large Models (Priority: P1) 🎯 MVP

**Goal**: deepseek-v3 and minimax-m1 are fully removed from the registry, the Modelfile is deleted, and provision.sh dead code is cleaned up. Provisioning either removed model exits with "Unsupported model".

**Independent Test**: `./scripts/provision.sh -m deepseek-v3` exits 1; `./scripts/provision.sh -m minimax-m1` exits 1. Neither name appears in the supported model list printed by the script. `shellcheck scripts/provision.sh` passes with 0 warnings.

### Implementation for User Story 1

- [x] T002 [P] [US1] Remove deepseek-v3 and minimax-m1 records from models/registry.conf (keep glm-4 and qwen3-coder unchanged)
- [x] T003 [P] [US1] Delete models/minimax-m1.Modelfile via git rm
- [x] T004 [US1] Remove Block 1 from scripts/provision.sh: the entire `if [[ "$MODEL_NAME" == "minimax-m1" && "$BACKEND" == "ollama" ]]` GGUF prerequisite check block (~line 200 per quickstart.md)
- [x] T005 [US1] Remove Block 2 from scripts/provision.sh: the `if [[ "$MODEL_NAME" == "minimax-m1" ]]` / `else` ollama-create branch (~line 360 per quickstart.md); replace with the unconditional `docker exec llm-server ollama pull "$OLLAMA_ID"` line only (depends on T004)
- [x] T006 [US1] Run `shellcheck scripts/provision.sh` and verify 0 warnings (depends on T004, T005)

**Checkpoint**: `./scripts/provision.sh -m deepseek-v3` exits 1; `./scripts/provision.sh -m minimax-m1` exits 1; `shellcheck` passes

---

## Phase 4: User Story 2 — Provision New Code-Focused Models on Consumer Hardware (Priority: P2)

**Goal**: Six new code-focused models are added to the registry with exact values from data-model.md. All six are provisionable via both Ollama and llama.cpp backends without manual setup.

**Independent Test**: Each new model ID appears in the provisioning script's supported model list. Each registry entry has valid values for all 8 columns. `./scripts/provision.sh -m starcoder2-3b` starts the Ollama server successfully.

### Implementation for User Story 2

- [x] T007 [US2] Add 6 new records to models/registry.conf, sorted alphabetically by id, using exact values from data-model.md §"Records Added" (depends on T002 — same file):
  ```
  codellama-7b|codellama:7b-instruct|4|8|stable|TheBloke/CodeLlama-7B-Instruct-GGUF|CodeLlama-7B-Instruct.Q4_K_M.gguf|8gb
  codegemma-7b|codegemma:7b|5|10|stable|bartowski/codegemma-7b-it-GGUF|codegemma-7b-it-Q4_K_M.gguf|8gb
  deepseek-coder-lite|deepseek-coder-v2:16b-lite-instruct-q4_K_M|10|12|stable|bartowski/DeepSeek-Coder-V2-Lite-Instruct-GGUF|DeepSeek-Coder-V2-Lite-Instruct-Q4_K_M.gguf|16gb
  starcoder2-3b|starcoder2:3b|2|4|stable|second-state/StarCoder2-3B-GGUF|starcoder2-3b-Q4_K_M.gguf|8gb
  starcoder2-7b|starcoder2:7b|5|8|stable|second-state/StarCoder2-7B-GGUF|starcoder2-7b-Q4_K_M.gguf|8gb
  starcoder2-15b|starcoder2:15b|10|20|stable|second-state/StarCoder2-15B-GGUF|starcoder2-15b-Q4_K_M.gguf|16gb
  ```
- [x] T008 [US2] Update the header NOTE comment in models/registry.conf: remove old size warnings for deepseek-v3/minimax-m1; add a note about the codestral-7b → codegemma-7b substitution

**Checkpoint**: models/registry.conf contains exactly 8 records sorted alphabetically; all 8 columns populated for each record

---

## Phase 5: User Story 3 — Consult Updated Documentation (Priority: P3)

**Goal**: README, example configs, and CLAUDE.md reflect the current 8-model lineup with no trace of removed models. A user with a 6 GB GPU can identify 3+ suitable models from the README alone.

**Independent Test**: README models table shows exactly 8 rows. `grep -r "deepseek-v3\|minimax-m1" README.md examples/ CLAUDE.md` returns no matches.

### Implementation for User Story 3

- [x] T009 [P] [US3] Update README.md:
  - Replace the models table with 8 rows (codellama-7b, codegemma-7b, deepseek-coder-lite, glm-4, qwen3-coder, starcoder2-3b, starcoder2-7b, starcoder2-15b) showing VRAM/RAM columns
  - Add a note that codegemma-7b substitutes the unavailable codestral-7b
  - Delete the `## MiniMax-M1 (Experimental)` section
  - Update the llama.cpp Backend section: per-model minimum tier table and model ID mapping table for the 8 current models
  - Add a hardware selection guide: which models suit 4 GB / 6 GB / 8 GB / 10 GB+ GPUs (use data-model.md §"Hardware Tier Guide")
- [x] T010 [P] [US3] Update examples/opencode/config.json:
  - Remove the deepseek-v3 model entry
  - Add 6 new model entries under the ollama provider (codellama-7b, codegemma-7b, deepseek-coder-lite, starcoder2-3b, starcoder2-7b, starcoder2-15b)
  - Update the `_llama_cpp_ids` comment block with llama.cpp model IDs for the new models
- [x] T011 [P] [US3] Update CLAUDE.md:
  - Replace the Supported models list (in Stack section) with the 8 current models
  - Add the codegemma-7b substitution note
  - Remove minimax-m1 references from Key Conventions (MiniMax-M1 GGUF note and Modelfile reference)

**Checkpoint**: README models table shows exactly 8 rows; no deepseek-v3 or minimax-m1 in user-facing docs; 6 GB GPU user can identify 3+ models

---

## Phase 6: Polish & Verification

**Purpose**: Final validation that all acceptance criteria are met

- [x] T012 Verify models/registry.conf final state matches data-model.md §"Complete registry.conf After Change" exactly (8 records, alphabetically sorted)
- [x] T013 [P] Verify models/minimax-m1.Modelfile no longer exists in the repository
- [x] T014 [P] Run `shellcheck scripts/provision.sh` one final time to confirm 0 warnings

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **US1 (Phase 3)**: Depends on T001 (read current state) — T002 and T003 can run in parallel; T004 → T005 → T006 are sequential (same file)
- **US2 (Phase 4)**: T007 depends on T002 (same file: registry.conf); T008 depends on T007
- **US3 (Phase 5)**: Can start after US1/US2 but touches different files — T009, T010, T011 are fully parallel
- **Polish (Phase 6)**: Depends on all prior phases

### User Story Dependencies

- **US1 (P1)**: Start after T001 — no story dependencies
- **US2 (P2)**: T007 depends on T002 (registry.conf); otherwise independent of US1 script changes
- **US3 (P3)**: Logically after US1+US2 (docs must reflect final 8-model set); all three tasks parallel

### Parallel Opportunities

- T002 (remove registry records) and T003 (delete Modelfile) can run in parallel — different files
- T004 and T005 are sequential — both edit scripts/provision.sh
- T009, T010, T011 are fully parallel — README, config.json, CLAUDE.md are separate files
- T013 and T014 in Polish phase can run in parallel

---

## Parallel Example: User Story 1

```bash
# These two tasks touch different files — run together:
Task T002: "Remove deepseek-v3 and minimax-m1 records from models/registry.conf"
Task T003: "Delete models/minimax-m1.Modelfile via git rm"

# Then sequentially (same file):
Task T004: "Remove Block 1 from scripts/provision.sh"
Task T005: "Remove Block 2 from scripts/provision.sh"
Task T006: "shellcheck scripts/provision.sh"
```

## Parallel Example: User Story 3

```bash
# All three touch different files — run together:
Task T009: "Update README.md"
Task T010: "Update examples/opencode/config.json"
Task T011: "Update CLAUDE.md"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Read current state (T001)
2. Complete Phase 3: US1 — remove impractical models (T002–T006)
3. **STOP and VALIDATE**: `./scripts/provision.sh -m deepseek-v3` exits 1; shellcheck passes
4. Continue to US2 + US3

### Incremental Delivery

1. US1 complete → impractical models blocked, script clean
2. US2 complete → 6 new models provisionable
3. US3 complete → docs accurate for all 8 models
4. Each phase adds value independently

---

## Notes

- This is a data-change feature — no new scripting logic is required
- All new models are handled automatically by the existing registry-driven provisioning
- Exact registry values must come from data-model.md §"Records Added" — do not infer
- The codestral-7b → codegemma-7b substitution must be documented wherever codestral-7b is mentioned
- shellcheck must pass after every provision.sh edit (check after T005 and again after T006)
