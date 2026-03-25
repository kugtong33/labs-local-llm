# Tasks: Local LLM Coding Assistant Setup

**Input**: Design documents from `/specs/001-local-llm-coding-setup/`
**Prerequisites**: plan.md ✓, spec.md ✓, research.md ✓, data-model.md ✓, contracts/ ✓, quickstart.md ✓

**Tests**: No test tasks — none requested in the feature specification.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US4)

## Path Conventions

Infrastructure/shell script project — flat root layout per plan.md:
- Scripts: `scripts/`
- Model configs: `models/`
- Agent config examples: `examples/`
- Root: `docker-compose.yml`, `.env.example`, `README.md`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization — directory structure and static configuration files

- [x] T001 Create project directory structure: `scripts/`, `models/`, `examples/opencode/`, `examples/continue/`, `examples/aider/`; add `.gitignore` ignoring `.env` and `*.gguf`
- [x] T002 [P] Create `.env.example` with all keys from data-model.md: `MODEL_NAME`, `MODE`, `LLM_PORT`, `GPU_DEVICE_ID`, `MODEL_CACHE_DIR`, `HF_TOKEN` — each with inline comment explaining valid values
- [x] T003 [P] Create `models/registry.conf` with pipe-delimited entries for all three models per data-model.md: `deepseek-v3`, `glm-4`, `minimax-m1` (id|ollama_id|min_vram_gb|min_ram_gb|status)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core Docker infrastructure that MUST be complete before any script can provision a container

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Create `docker-compose.yml` with two Ollama service variants: `llm-gpu` (profile: gpu, `deploy.resources` NVIDIA device reservation via `${GPU_DEVICE_ID}`) and `llm-cpu` (profile: cpu, no GPU block); both use `ollama/ollama:latest`, `model-cache` named volume mounted to `/root/.ollama`, port `${LLM_PORT:-11434}:11434`, and healthcheck polling `GET /` with 180s start period and 10 retries; named volume `model-cache` uses local bind driver pointing to `${MODEL_CACHE_DIR:-/opt/llm-models}`
- [x] T005 [P] Create `models/minimax-m1.Modelfile` with Ollama Modelfile template for importing MiniMax-M1 from a GGUF file at `/models/gguf/minimax-m1.gguf`, including the correct chat template and stop token per data-model.md

**Checkpoint**: `docker compose --profile cpu up -d` (no GPU required) starts Ollama container and `curl http://localhost:11434/` returns `"Ollama is running"`

---

## Phase 3: User Story 1 — Spin Up a Local LLM for Coding (Priority: P1) 🎯 MVP

**Goal**: A developer can start a local LLM inference server with a single command, on either GPU or CPU hardware.

**Independent Test**: Run `./scripts/provision.sh -m glm-4 -M cpu`, wait for container to be healthy, then `curl http://localhost:11434/v1/models` — response must contain `"id": "glm4:latest"`.

### Implementation for User Story 1

- [x] T006 [US1] Implement `scripts/provision.sh` per contracts/cli.md: parse `-m`, `-M`, `-p`, `-g` flags; validate model name against `models/registry.conf`; check Docker is installed and daemon is running; check port availability with `lsof`; detect GPU via `nvidia-smi` + `docker info | grep nvidia` when mode is `auto`; stop any running `llm-server` container; export `MODEL_NAME` (resolved to Ollama ID from registry), `LLM_PORT`, `GPU_DEVICE_ID` and run `docker compose --profile $MODE up -d --pull always`; for minimax-m1 run `ollama create minimax-m1 -f models/minimax-m1.Modelfile` after container is healthy; print endpoint URL and usage hints on success; use exit codes 0–4 per contract
- [x] T007 [US1] Smoke test `provision.sh`: start container with `./scripts/provision.sh -m glm-4 -M cpu`, poll `docker compose ps` until healthy, then verify `curl -sf http://localhost:11434/v1/models` returns JSON with a model `id` field — fix any issues found

**Checkpoint**: US1 complete — single command provisions a running Ollama inference server serving GLM-4 on CPU or GPU

---

## Phase 4: User Story 2 — Connect an AI Coding Agent (Priority: P2)

**Goal**: OpenCode, Continue, and Aider can connect to the local LLM server using copy-paste config and receive valid streaming completions.

**Independent Test**: With server running from US1, run `curl -X POST http://localhost:11434/v1/chat/completions -H "Content-Type: application/json" -d '{"model":"glm4:latest","messages":[{"role":"user","content":"hi"}],"stream":true}'` — response must be SSE lines ending with `data: [DONE]`.

### Implementation for User Story 2

- [x] T008 [P] [US2] Create `examples/opencode/config.toml` with `[model]` block: `provider = "openai"`, `model = "glm4:latest"`, `base_url = "http://localhost:11434/v1"`, `api_key = "local"`; add comment explaining the model value must match `/v1/models` response id
- [x] T009 [P] [US2] Create `examples/continue/config.json` with `models` array entry for Local GLM-4: `provider: "openai"`, `apiBase: "http://localhost:11434/v1"`, `apiKey: "local"`, `model: "glm4:latest"`, `contextLength: 32768`; include `tabAutocompleteModel` entry using same endpoint
- [x] T010 [P] [US2] Create `examples/aider/.aider.conf.yml` with `model: openai/glm4:latest`, `openai-api-base: http://localhost:11434/v1`, `openai-api-key: local`, `max-tokens: 8192`; add comment about `openai/` prefix requirement
- [x] T011 [US2] Smoke test streaming API: with server running, execute the curl command from the Independent Test above and confirm: (1) response content-type is `text/event-stream`, (2) each `data:` line is valid JSON with `choices[0].delta`, (3) stream terminates with `data: [DONE]` — fix any issues found

**Checkpoint**: US2 complete — AI coding agents can connect and receive valid streaming responses

---

## Phase 5: User Story 3 — Manage the LLM Setup via Shell Scripts (Priority: P3)

**Goal**: Four scripts (`provision`, `clean`, `update`, `status`) cover the full container lifecycle with no manual Docker commands required.

**Independent Test**: Run the full lifecycle: `provision.sh -m glm-4 -M cpu` → `status.sh` (shows running) → `update.sh -m glm-4` (restarts) → `clean.sh` (stops) → `status.sh` (shows not running).

### Implementation for User Story 3

- [x] T012 [US3] Implement `scripts/clean.sh` per contracts/cli.md: parse `--keep-models` (default) and `--purge-models` flags; stop the `llm-server` container via `docker compose down --remove-orphans`; if `--purge-models` also run `docker volume rm llm-model-cache`; print summary of what was removed; exit 0 even if no container was running (idempotent)
- [x] T013 [US3] Implement `scripts/update.sh` per contracts/cli.md: parse `-m MODEL`, `-M MODE`, `-p PORT` flags; validate model name against registry; run `docker exec llm-server ollama pull $OLLAMA_ID` (or re-provision if container is not running); restart the server by calling `provision.sh` with the same model and mode; print result
- [x] T014 [US3] Implement `scripts/status.sh` per contracts/cli.md: check if `llm-server` container is running via `docker ps`; if running: fetch loaded model from `curl /v1/models`, extract container CPU/memory via `docker stats --no-stream`, fetch GPU VRAM via `nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader` (skip if CPU mode), display formatted summary box with model, mode, port, endpoint, uptime, CPU%, memory, VRAM; if not running: print "no server running" hint message

**Checkpoint**: US3 complete — full lifecycle (provision, update, status, clean) works via scripts with no Docker commands

---

## Phase 6: User Story 4 — Choose Between Supported Models (Priority: P4)

**Goal**: All three supported models (DeepSeek-V3, GLM-4, MiniMax-M1) can be provisioned and switched using only the provision script.

**Independent Test**: Run `./scripts/provision.sh -m deepseek-v3 -M cpu` (or GPU if available) — verify it starts without error; then run `./scripts/provision.sh -m foo-invalid` — verify exit code 1 with error listing supported models.

### Implementation for User Story 4

- [x] T015 [P] [US4] Update `docker-compose.yml` to pass model-specific parameters via environment variables: add `OLLAMA_MAX_LOADED_MODELS=1` and `OLLAMA_KEEP_ALIVE=24h` to both service variants; add `OLLAMA_ORIGINS=*` to allow agent connections; ensure `OLLAMA_HOST=0.0.0.0` so the server listens on all interfaces inside the container
- [x] T016 [P] [US4] Update `scripts/provision.sh` to handle MiniMax-M1 post-start step: after container health check passes, check if model is `minimax-m1`; if so, verify `${MODEL_CACHE_DIR}/minimax-m1.gguf` exists (error with instructions if not), then run `docker exec llm-server ollama create minimax-m1 -f /models/minimax-m1.Modelfile` and `docker exec llm-server ollama pull minimax-m1`; add `[EXPERIMENTAL]` warning in output for minimax-m1

**Checkpoint**: US4 complete — all three models selectable; invalid model names produce helpful errors

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, script quality, and end-to-end validation

- [x] T017 [P] Create `README.md` at repo root with: project description, prerequisites section (Docker, NVIDIA toolkit install command for Ubuntu), model comparison table from quickstart.md, quick start commands, script reference table (provision/clean/update/status with args), troubleshooting section from quickstart.md
- [x] T018 [P] Run `shellcheck` on all four scripts: `shellcheck scripts/provision.sh scripts/clean.sh scripts/update.sh scripts/status.sh`; fix all warnings (SC2006, SC2046, SC2086, SC2155 etc.) until shellcheck exits 0
- [x] T019 End-to-end validation of `quickstart.md` walkthrough: execute every command block in order (provision GLM-4 CPU → verify /v1/models → configure one agent → clean); update any commands in quickstart.md that fail or produce different output than documented

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Foundational — scripts can't run without docker-compose.yml
- **US2 (Phase 4)**: Depends on US1 — needs a running server to verify streaming API
- **US3 (Phase 5)**: Depends on US1 — clean/update/status wrap the same container
- **US4 (Phase 6)**: Depends on US1 and US3 — model switching uses provision + clean
- **Polish (Phase 7)**: Depends on all user stories complete

### User Story Dependencies

- **US1 (P1)**: Depends only on Foundational — no story dependencies
- **US2 (P2)**: Depends on US1 (server must be running to test streaming)
- **US3 (P3)**: Depends on US1 (container must exist to clean/update/status)
- **US4 (P4)**: Depends on US1 and US3 (model switching = provision + clean cycle)

### Within Each User Story

- Registry and config files before script implementation
- Implementation before smoke test
- Smoke tests must pass before marking story complete

### Parallel Opportunities

- T002 and T003 can run in parallel (different files, Phase 1)
- T004 and T005 can run in parallel (different files, Phase 2)
- T008, T009, T010 can all run in parallel (different example files, Phase 4)
- T015 and T016 can run in parallel (different files, Phase 6)
- T017 and T018 can run in parallel (documentation vs. linting, Phase 7)

---

## Parallel Example: Phase 1

```text
# Run in parallel immediately:
Task T002: Create .env.example
Task T003: Create models/registry.conf
```

## Parallel Example: US2 Agent Configs (T008–T010)

```text
# Run in parallel after T006 (provision.sh) is complete:
Task T008: Create examples/opencode/config.toml
Task T009: Create examples/continue/config.json
Task T010: Create examples/aider/.aider.conf.yml
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001–T003)
2. Complete Phase 2: Foundational (T004–T005)
3. Complete Phase 3: US1 — provision.sh + smoke test (T006–T007)
4. **STOP and VALIDATE**: `./scripts/provision.sh -m glm-4 -M cpu` → curl /v1/models responds
5. At this point: local LLM is running and usable manually

### Incremental Delivery

1. Setup + Foundational → Docker Compose infrastructure ready
2. US1 → LLM server provisionable → **MVP: manually usable**
3. US2 → Agent configs → **coding agents can connect**
4. US3 → All management scripts → **fully managed lifecycle**
5. US4 → Multi-model support → **flexible model selection**
6. Polish → Production-ready documentation and quality

### Single Developer Sequence

1. T001 → T002, T003 (parallel) → T004, T005 (parallel) → T006 → T007
2. Validate MVP: server runs, API responds
3. T008, T009, T010 (parallel) → T011
4. T012 → T013 → T014
5. T015, T016 (parallel)
6. T017, T018 (parallel) → T019

---

## Notes

- [P] tasks = different files, no dependencies on each other
- [US#] label maps task to specific user story for traceability
- Each user story is independently testable after its smoke test passes
- No test tasks generated — none requested in the feature specification
- Commit after each phase checkpoint at minimum
- `clean.sh` defaults to `--keep-models` to prevent accidental deletion of large model files
- MiniMax-M1 is experimental — T016 should include `[EXPERIMENTAL]` warnings prominently
- `shellcheck` is a dependency for T018 — install with `sudo apt-get install shellcheck`
