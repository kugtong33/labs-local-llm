# Tasks: Add llama.cpp Backend Support

**Input**: Design documents from `/specs/005-llama-cpp-backend/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓, quickstart.md ✓

**Tests**: No test tasks generated — feature specification does not request TDD approach. Validation is performed via the manual checklist in `quickstart.md`.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US4, maps to spec.md)
- Exact file paths are included in each description

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Minimal project-level housekeeping needed before any work begins.

- [x] T001 Add `.llm-state` entry to `.gitignore` (runtime state file must not be committed)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Config files, Docker Compose services, and cleanup script changes that MUST be complete before any user story can be implemented or tested.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T002 [P] Extend `models/registry.conf`: update header comment to document new 8-column format (`id|ollama_id|min_vram_gb|min_ram_gb|status|gguf_hf_repo|gguf_filename|min_vram_tier`) and append 3 new pipe-delimited fields to all 4 existing model records using values from `specs/005-llama-cpp-backend/data-model.md` §"Model Registry Entry"
- [x] T003 [P] Create `models/vram-tiers.conf` with header comment documenting 6-column format and 4 tier records (8gb, 16gb, 24gb, 32gb) using the exact field values specified in `specs/005-llama-cpp-backend/data-model.md` §"VRAM Tier Configuration"
- [x] T004 Add two new services to `docker-compose.yml` using a new YAML anchor `x-llamacpp-base`: `llm-llamacpp-gpu` (profile `llamacpp-gpu`, image `ghcr.io/ggml-org/llama.cpp:server-cuda`, NVIDIA GPU reservation) and `llm-llamacpp-cpu` (profile `llamacpp-cpu`, image `ghcr.io/ggml-org/llama.cpp:server`); both use `container_name: llm-server`, port mapping `${LLM_PORT:-11434}:8080`, volume `model-cache:/models`, parameterized `command:` block consuming `LLAMACPP_MODEL_FILE`, `LLAMACPP_CTX_SIZE`, `LLAMACPP_N_GPU_LAYERS`, `LLAMACPP_BATCH_SIZE`, `LLAMACPP_UBATCH_SIZE` env vars, and health check `["CMD-SHELL", "curl -sf http://localhost:8080/v1/models || exit 1"]` with `start_period: 180s` — see `specs/005-llama-cpp-backend/contracts/api-contract.md` and `data-model.md` §"Docker Compose Service Definitions"
- [x] T005 [P] Update `scripts/clean.sh`: add `--profile llamacpp-gpu --profile llamacpp-cpu` to all `docker compose down` invocations (both `--purge-models` and default branches); after containers are stopped, add `rm -f "$PROJECT_DIR/.llm-state"` to delete the state file; ensure `shellcheck scripts/clean.sh` passes with 0 warnings

**Checkpoint**: Config files parseable, compose services defined, cleanup works for both backends — user story implementation can now begin.

---

## Phase 3: User Story 1 — Provision a Model via llama.cpp Backend (Priority: P1) 🎯 MVP

**Goal**: `./scripts/provision.sh -m glm-4 -b llama.cpp` starts a llama.cpp inference server and the OpenAI-compatible API responds on port 11434. Existing `./scripts/provision.sh -m glm-4` (no `-b` flag) continues to use Ollama unchanged.

**Independent Test**: Run `./scripts/provision.sh -m glm-4 -b llama.cpp`, then `curl -sf http://localhost:11434/v1/models` → must return 200 with JSON body. Run `./scripts/provision.sh -m glm-4` (no `-b`) → must use Ollama profile.

### Implementation for User Story 1

- [x] T006 [US1] In `scripts/provision.sh`: extend the `getopts` string from `"m:M:p:g:h"` to `"m:M:p:g:b:V:h"`; add `BACKEND="ollama"` and `VRAM_TIER="8gb"` defaults at the top of the Defaults section; add `b)` and `V)` case branches in the getopts `case` block
- [x] T007 [US1] In `scripts/provision.sh`: add post-getopts BACKEND validation — if `BACKEND` is not `ollama` or `llama.cpp`, print `"ERROR: Invalid backend '$BACKEND'. Must be: ollama or llama.cpp."` to stderr and exit 1; reference `specs/005-llama-cpp-backend/contracts/cli-flags.md` for exact error message format
- [x] T008 [US1] In `scripts/provision.sh`: add `download_gguf()` function that accepts `(hf_repo, filename, cache_dir)` — if `hf_repo=local` check file exists (exit 1 with path if missing); otherwise check if `$cache_dir/$filename` exists and skip download if present; if download needed, run `curl -L -C - --progress-bar -o "$cache_dir/$filename" "https://huggingface.co/$hf_repo/resolve/main/$filename"`; exit 1 if curl fails; read `gguf_hf_repo` (col 6) and `gguf_filename` (col 7) from `REGISTRY_LINE` (already parsed via awk) and call `download_gguf` when `BACKEND=llama.cpp`
- [x] T009 [US1] In `scripts/provision.sh`: add llama.cpp Docker Compose profile selection branch — when `BACKEND=llama.cpp`, set `COMPOSE_PROFILE="llamacpp-$RESOLVED_MODE"` and export `LLAMACPP_MODEL_FILE="$gguf_filename"`; the existing `docker compose --profile "$RESOLVED_MODE" up -d --pull always` call must be replaced with a branch that uses `--profile "$COMPOSE_PROFILE"` when backend is llama.cpp (use `if/else` branching on `$BACKEND`)
- [x] T010 [US1] In `scripts/provision.sh`: update the startup health-check wait loop to branch on `$BACKEND` — when `llama.cpp`, poll `curl -sf "http://localhost:${LLM_PORT}/v1/models"` (not `/`); keep existing `curl -sf "http://localhost:${LLM_PORT}/"` for Ollama; update the failure error message to show the correct log command per backend (`docker compose logs llm-llamacpp-$RESOLVED_MODE` vs `docker compose logs llm-$RESOLVED_MODE`)
- [x] T011 [US1] In `scripts/provision.sh`: add atomic `.llm-state` write after the health check succeeds — write to `$PROJECT_DIR/.llm-state.tmp` first, then `mv "$PROJECT_DIR/.llm-state.tmp" "$PROJECT_DIR/.llm-state"`; include all state keys defined in `specs/005-llama-cpp-backend/data-model.md` §"LLM State File" (`backend`, `model`, `mode`, `port`; when llama.cpp also `vram_tier` and `model_file`); write state for Ollama provisioning too (with `backend=ollama`)
- [x] T012 [US1] In `scripts/provision.sh`: update the `#` header comment block at the top of the file to add `-b BACKEND` and `-V VRAM_TIER` to the Usage line and Options section; run `shellcheck scripts/provision.sh` and fix all warnings before considering this task done

**Checkpoint**: `./scripts/provision.sh -m glm-4 -b llama.cpp` starts the server, API responds, `.llm-state` is written. Ollama provisioning unchanged. `shellcheck` passes.

---

## Phase 4: User Story 2 — Select VRAM-Optimized Configuration (Priority: P2)

**Goal**: `./scripts/provision.sh -m glm-4 -b llama.cpp -V 16gb` starts the server with 16 GB tier parameters (8192 ctx, 1024 batch). Omitting `-V` defaults to `8gb` tier. Invalid tier values exit 1 with tier list.

**Independent Test**: Run `./scripts/provision.sh -m glm-4 -b llama.cpp -V 16gb`; inspect the running container's effective command via `docker inspect llm-server` → `Args` must include `--ctx-size 8192` and `--batch-size 1024`. Run with `-V 48gb` → must exit 1.

### Implementation for User Story 2

- [x] T013 [US2] In `scripts/provision.sh`: add VRAM_TIER validation after BACKEND validation — if `VRAM_TIER` is not one of `8gb`, `16gb`, `24gb`, `32gb`, print `"ERROR: Invalid VRAM tier '$VRAM_TIER'. Must be: 8gb, 16gb, 24gb, or 32gb."` to stderr and exit 1
- [x] T014 [US2] In `scripts/provision.sh`: add `lookup_vram_tier()` function that reads `$PROJECT_DIR/models/vram-tiers.conf` and returns the row matching `$VRAM_TIER`; extract `LLAMACPP_CTX_SIZE` (col 2), `LLAMACPP_N_GPU_LAYERS` (col 3), `LLAMACPP_BATCH_SIZE` (col 4), `LLAMACPP_UBATCH_SIZE` (col 5) using `awk -F'|'`; call this function when `BACKEND=llama.cpp` and export the four variables; exit 1 with error if `vram-tiers.conf` is missing or tier not found
- [x] T015 [US2] In `scripts/provision.sh`: add min-tier warning — read `min_vram_tier` (col 8) from `REGISTRY_LINE`; define tier order `8gb < 16gb < 24gb < 32gb` (use an array or positional mapping); if selected `VRAM_TIER` is ranked below `min_vram_tier`, emit `"WARNING: '$MODEL_NAME' recommends at least $min_vram_tier VRAM. Running on $VRAM_TIER may cause OOM errors."` to stderr; do not block provisioning
- [x] T016 [US2] In `scripts/provision.sh`: ensure all four `LLAMACPP_*` variables are exported (via `export`) before the `docker compose up` invocation in the llama.cpp branch; confirm `MODEL_CACHE_DIR`, `LLM_PORT`, and `GPU_DEVICE_ID` are also exported (they already are for Ollama — verify llama.cpp path does the same); run `shellcheck scripts/provision.sh` and fix all warnings

**Checkpoint**: VRAM tier flag fully functional. Container starts with tier-specific parameters. `shellcheck` passes.

---

## Phase 5: User Story 3 — Use Any Supported Model with llama.cpp (Priority: P3)

**Goal**: All four registry models (glm-4, deepseek-v3, minimax-m1, qwen3-coder) can be provisioned with `-b llama.cpp`. Missing local GGUF for minimax-m1 exits with a clear error. Model-not-in-registry exits 1 (existing behavior unchanged).

**Independent Test**: Run `./scripts/provision.sh -m minimax-m1 -b llama.cpp` without the GGUF in cache → must exit 1 with path message. Confirm `./scripts/provision.sh -m notamodel -b llama.cpp` exits 1 (existing registry check).

### Implementation for User Story 3

- [x] T017 [US3] Verify the GGUF filenames in `models/registry.conf` columns 6–7 for `glm-4`, `qwen3-coder`, and `deepseek-v3` against the actual files published on their respective HuggingFace repositories (check that `Q4_K_M.gguf` naming matches published files); update any incorrect filenames or HF repo paths in `models/registry.conf`; document findings in a comment at the top of `models/registry.conf`
- [x] T018 [US3] In `scripts/provision.sh`: extend the existing minimax-m1 GGUF check (currently at line ~176) so it also fires when `BACKEND=llama.cpp` (currently it only guards the Ollama path); the existing check already uses `$MODEL_CACHE_DIR/$gguf_filename` — confirm the check runs before `download_gguf()` is called (or replace the direct `GGUF_PATH` check with the `download_gguf` function's `local` path handling); ensure the error message prints the expected `$MODEL_CACHE_DIR/minimax-m1.gguf` path
- [x] T019 [US3] In `scripts/provision.sh`: confirm that the existing model-not-in-registry validation (checks `REGISTRY_LINE` is non-empty, exits 1) runs before any `-b`-specific logic, so it applies to both backends with no additional changes; add a brief comment in the source marking this validation as backend-agnostic

**Checkpoint**: All four models handled correctly. minimax-m1 missing-GGUF error works. Unrecognised model exits 1 for both backends. `shellcheck` passes.

---

## Phase 6: User Story 4 — llama.cpp Setup Documentation (Priority: P4)

**Goal**: README contains a complete llama.cpp section. Example configs include llama.cpp model IDs. Users can complete setup without external resources.

**Independent Test**: Follow only the README llama.cpp section to provision glm-4 — no external lookups needed. Confirm all four VRAM tier examples are present.

### Implementation for User Story 4

- [x] T020 [P] [US4] Add a "llama.cpp Backend" section to `README.md` containing: prerequisites note (Docker + NVIDIA Container Toolkit already required), VRAM tier command examples for all four tiers using `glm-4`, a per-model minimum tier table (glm-4→8gb, qwen3-coder→8gb, minimax-m1→24gb, deepseek-v3→32gb with size warning), a note on GGUF auto-download (large files, resumable, first-run time), and the API endpoint note (same URL, different model ID format); reference `specs/005-llama-cpp-backend/contracts/api-contract.md` §"Model ID Mapping"
- [x] T021 [P] [US4] Update `examples/opencode/config.json`: add a comment block (or a `_comment` key) documenting the llama.cpp model IDs alongside the existing Ollama IDs for each supported model, so users know which `model` value to use per backend; reference `specs/005-llama-cpp-backend/contracts/api-contract.md` §"Model ID Mapping"
- [x] T022 [P] [US4] Update `CLAUDE.md`: add `llama.cpp` to the Supported models section noting it is an alternative backend; add `-b llama.cpp` and `-V VRAM_TIER` flag examples to the Commands section

**Checkpoint**: Documentation complete. User Story 4 acceptance scenarios pass.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: status.sh and update.sh extensions, final shellcheck validation, and end-to-end smoke test.

- [x] T023 [P] Update `scripts/status.sh`: read `.llm-state` using `grep` (not `source`) as shown in `specs/005-llama-cpp-backend/quickstart.md` §"status.sh state file reading"; when `BACKEND=llama.cpp`, insert a `Backend:` row and a `VRAM Tier:` row in the display table immediately after the `Model:` row; read the tier description string from `models/vram-tiers.conf` col 6 for the `VRAM Tier:` display label; when `.llm-state` is absent, display defaults (no Backend/VRAM Tier rows — backward compatible); run `shellcheck scripts/status.sh` and fix all warnings
- [x] T024 [P] Update `scripts/update.sh`: extend `getopts` string from `"m:M:p:h"` to `"m:M:p:b:V:h"` and add `-b BACKEND` and `-V VRAM_TIER` option branches; if flags are omitted, read `BACKEND` and `VRAM_TIER` from `$PROJECT_DIR/.llm-state` using `grep` (fall back to `ollama` / `8gb` if state file absent); for `BACKEND=llama.cpp`: call `"$SCRIPT_DIR/provision.sh" -m "$MODEL_NAME" -M "$MODE" -p "$LLM_PORT" -b "$BACKEND" -V "$VRAM_TIER"` instead of the Ollama `docker exec ollama pull` path; update the header comment to document new flags; run `shellcheck scripts/update.sh` and fix all warnings
- [x] T025 Run `shellcheck scripts/provision.sh scripts/status.sh scripts/clean.sh scripts/update.sh` — all four scripts must exit 0 with 0 warnings; fix any remaining issues before marking complete
- [x] T026 Execute the full quickstart.md test checklist end-to-end: provision glm-4 with llama.cpp (default tier), verify API response, verify status.sh output, run clean.sh, verify `.llm-state` deleted; provision with `-V 16gb` and confirm tier params in container; attempt provisioning with invalid backend and invalid tier values and confirm correct exit codes

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1. **BLOCKS all user stories.**
- **User Story 1 (Phase 3)**: Depends on Phase 2 completion.
- **User Story 2 (Phase 4)**: Depends on Phase 3 (T006–T012) — `-V` flag parsing builds on top of `-b` flag parsing in the same file.
- **User Story 3 (Phase 5)**: Depends on Phase 3 (T008 download_gguf must exist). Can start alongside Phase 4 after T008 is complete.
- **User Story 4 (Phase 6)**: Depends on Phase 3 completion (needs working command examples to document). Can run in parallel with Phases 4 and 5.
- **Polish (Phase 7)**: Depends on all User Story phases completing.

### User Story Dependencies

- **US1 (P1)**: Starts after Phase 2. Core provisioning path. No dependency on US2–US4.
- **US2 (P2)**: Starts after US1 T006 is merged (shares `provision.sh` — must apply on top of US1 changes).
- **US3 (P3)**: Starts after US1 T008 (download_gguf function must exist). T017 (GGUF verification) can run independently in parallel.
- **US4 (P4)**: Starts after US1 (needs accurate command examples). All three US4 tasks are independent of each other [P].

### Within Each User Story

- provision.sh tasks (T006–T012, T013–T016, T018–T019) are sequential — they modify the same file.
- T017 (GGUF verification research task) can run in parallel with any other task.
- T020, T021, T022 (documentation) touch different files — all parallelizable [P].
- T023 (status.sh), T024 (update.sh) touch different files — parallelizable [P].

---

## Parallel Opportunities

### Phase 2 (run simultaneously after T001)

```
T002: Update models/registry.conf
T003: Create models/vram-tiers.conf
T004: Update docker-compose.yml
T005: Update scripts/clean.sh
```

### User Story 4 (run simultaneously after Phase 3)

```
T020: README.md llama.cpp section
T021: examples/opencode/config.json model ID notes
T022: CLAUDE.md commands update
```

### Phase 7 (run simultaneously after all US phases)

```
T023: scripts/status.sh update
T024: scripts/update.sh update
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001)
2. Complete Phase 2: Foundational (T002–T005) — **CRITICAL, blocks everything**
3. Complete Phase 3: User Story 1 (T006–T012)
4. **STOP and VALIDATE**: `./scripts/provision.sh -m glm-4 -b llama.cpp` starts server, API responds.
5. Ship MVP: llama.cpp backend works for glm-4 at 8 GB default configuration.

### Incremental Delivery

1. MVP (US1) → glm-4 provisions with llama.cpp
2. Add US2 → VRAM tier selection works for all tiers
3. Add US3 → all 4 models supported, minimax-m1 edge case handled
4. Add US4 → documentation complete
5. Polish → status/update scripts extended, shellcheck clean

### Single-Developer Sequence

```
T001 → T002+T003+T004+T005 (parallel) → T006 → T007 → T008 → T009 → T010 → T011 → T012
→ T013 → T014 → T015 → T016 → T017+T018+T019 (T017 can start earlier)
→ T020+T021+T022 (parallel) → T023+T024 (parallel) → T025 → T026
```

---

## Notes

- `[P]` tasks touch different files and have no incomplete dependencies — safe to run in parallel.
- `[Story]` label maps each task to its user story for traceability back to `spec.md`.
- All `provision.sh` tasks (T006–T016, T018–T019) are sequential — same file edits.
- `shellcheck` must pass with 0 warnings after each script modification (enforced in T005, T012, T016, T023, T024, and T025).
- T017 is a verification/research task (check HF repos) — complete it before T002 if GGUF filenames need correction.
- The `.llm-state` file written in T011 is consumed by T023 (status.sh) and T024 (update.sh) — those tasks depend on T011 being stable.
- Commit after each completed phase or logical group.
- Stop at any phase checkpoint to validate the user story independently before proceeding.
