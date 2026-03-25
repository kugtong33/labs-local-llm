# Implementation Plan: Add llama.cpp Backend Support

**Branch**: `005-llama-cpp-backend` | **Date**: 2026-03-25 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/005-llama-cpp-backend/spec.md`

## Summary

Add `llama.cpp` as a second inference backend alongside Ollama. Users select it with a new `-b llama.cpp` flag on `provision.sh`, paired with a `-V` VRAM tier flag (`8gb` default, `16gb`, `24gb`, `32gb`) that pre-configures llama-server parameters for their GPU memory budget. All four existing models (glm-4, deepseek-v3, minimax-m1, qwen3-coder) are supported via GGUF files auto-downloaded from Hugging Face. The llama.cpp server runs in Docker (`ghcr.io/ggml-org/llama.cpp:server-cuda` / `:server`) and exposes the same OpenAI-compatible API on the same port scheme as Ollama. Existing Ollama commands are fully backward-compatible.

## Technical Context

**Language/Version**: Bash 5+
**Primary Dependencies**: Docker Engine 24+, Docker Compose v2, `ghcr.io/ggml-org/llama.cpp:server` / `:server-cuda`, NVIDIA Container Toolkit (optional, GPU mode)
**Storage**: Bind-mount volume (`model-cache` → `$MODEL_CACHE_DIR`). GGUF files stored alongside existing Ollama model data in the same directory.
**Testing**: `shellcheck` (static analysis, zero-warning requirement); manual end-to-end smoke tests per quickstart checklist.
**Target Platform**: Linux (Ubuntu 22.04+); same environment as existing project.
**Project Type**: CLI toolset (Bash scripts + Docker Compose infrastructure).
**Performance Goals**: Same as Ollama baseline — server starts and accepts requests within 3 minutes. VRAM tier configs deliver measurably differentiated context windows across tiers.
**Constraints**: Backward compatibility with all existing Ollama commands. Zero new mandatory prerequisites (curl already required; Docker already required). shellcheck must pass on all modified scripts.
**Scale/Scope**: 4 models, 4 VRAM tiers, 2 hardware modes (GPU/CPU). Single-server local inference.

## Constitution Check

The project constitution file (`/.specify/memory/constitution.md`) contains only template placeholders — no project-specific principles have been defined. No constitution gates to enforce.

**Post-design re-check**: N/A (no constitution principles defined).

## Project Structure

### Documentation (this feature)

```text
specs/005-llama-cpp-backend/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 research decisions
├── data-model.md        # Entities: registry format, VRAM tiers, state file, compose services
├── quickstart.md        # Developer quickstart and implementation notes
├── contracts/
│   ├── cli-flags.md     # CLI flag contracts for all four scripts
│   ├── api-contract.md  # OpenAI-compatible API contract (both backends)
│   └── registry-format.md  # File format contracts for registry.conf, vram-tiers.conf, .llm-state
└── tasks.md             # Phase 2 output (/speckit.tasks command — NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
docker-compose.yml          # +2 new services: llm-llamacpp-gpu, llm-llamacpp-cpu

models/
├── registry.conf           # Extended: +3 columns (gguf_hf_repo, gguf_filename, min_vram_tier)
└── vram-tiers.conf         # NEW: 4 VRAM tier parameter bundles

scripts/
├── provision.sh            # Extended: -b and -V flags; GGUF download; llama.cpp startup path
├── status.sh               # Extended: Backend and VRAM Tier rows; reads .llm-state
├── clean.sh                # Extended: llamacpp profiles in compose down; deletes .llm-state
└── update.sh               # Extended: reads .llm-state; re-provisions for llama.cpp

.llm-state                  # RUNTIME (gitignored): active backend/tier/model state
.gitignore                  # +.llm-state entry
```

**Structure Decision**: Single project (existing layout). All changes are in-place modifications or additive new files. No new directories required at the repository root.

## Complexity Tracking

No constitution violations. No complexity justification required.

---

## Implementation Phases

### Phase A: Infrastructure (docker-compose.yml + registry files)

**Goal**: All new configuration files and Docker Compose services in place. No script changes yet.

**Deliverables**:

1. **`docker-compose.yml`** — Add two llama.cpp services using a new YAML anchor `x-llamacpp-base`:
   - `llm-llamacpp-gpu` (profile: `llamacpp-gpu`): image `ghcr.io/ggml-org/llama.cpp:server-cuda`, port `${LLM_PORT:-11434}:8080`, NVIDIA GPU reservation.
   - `llm-llamacpp-cpu` (profile: `llamacpp-cpu`): image `ghcr.io/ggml-org/llama.cpp:server`, same port mapping, no GPU.
   - Both services: `container_name: llm-server`, volume `model-cache:/models`, parameterized command via `LLAMACPP_*` env vars, health check on `GET /v1/models`.

2. **`models/registry.conf`** — Extend all four existing records with columns 6–8 (`gguf_hf_repo`, `gguf_filename`, `min_vram_tier`). Update file header comment to document new format.

3. **`models/vram-tiers.conf`** (new file) — Define all four tiers with the 6-column format documented in `contracts/registry-format.md`.

4. **`.gitignore`** — Add `.llm-state` entry.

**Acceptance**: `docker compose config --profiles` shows `llamacpp-gpu` and `llamacpp-cpu` profiles. `models/registry.conf` and `models/vram-tiers.conf` parse correctly with `awk -F'|'`.

---

### Phase B: provision.sh Extension

**Goal**: `provision.sh` supports `-b llama.cpp` and `-V VRAM_TIER` flags end-to-end.

**Deliverables**:

1. **Flag parsing**: Extend `getopts` string from `"m:M:p:g:h"` to `"m:M:p:g:b:V:h"`. Add `BACKEND="ollama"` and `VRAM_TIER="8gb"` defaults.

2. **Flag validation**: After getopts loop, validate `BACKEND` and `VRAM_TIER` values. Exit 1 on invalid values.

3. **VRAM tier lookup**: When `BACKEND=llama.cpp`, read `models/vram-tiers.conf` to populate `LLAMACPP_CTX_SIZE`, `LLAMACPP_N_GPU_LAYERS`, `LLAMACPP_BATCH_SIZE`, `LLAMACPP_UBATCH_SIZE`.

4. **Min tier warning**: When `BACKEND=llama.cpp`, compare selected `VRAM_TIER` against model's `min_vram_tier` (col 8 of registry). If selected tier is below minimum, emit WARNING to stderr and continue.

5. **GGUF download**: Add `download_gguf()` function. Check if `$MODEL_CACHE_DIR/$gguf_filename` exists; if not, run `curl -L -C - --progress-bar -o "$MODEL_CACHE_DIR/$gguf_filename" "https://huggingface.co/$gguf_hf_repo/resolve/main/$gguf_filename"`. Skip if `gguf_hf_repo=local` (validate local file instead — exit 1 if missing).

6. **Docker Compose profile selection**: When `BACKEND=llama.cpp`, use profile `llamacpp-$RESOLVED_MODE` instead of `$RESOLVED_MODE`. Export all `LLAMACPP_*` env vars before `docker compose up`.

7. **Health check branch**: Use `curl -sf "http://localhost:${LLM_PORT}/v1/models"` when `BACKEND=llama.cpp`; use `curl -sf "http://localhost:${LLM_PORT}/"` for `ollama` (existing behavior).

8. **State file**: Write `.llm-state` after successful health check. Use atomic write pattern (write to `.llm-state.tmp`, then `mv`).

9. **Usage string**: Update the `#` header comment block to document `-b` and `-V` flags.

**Acceptance**: All acceptance scenarios in User Stories 1, 2, 3 pass. `shellcheck scripts/provision.sh` exits 0 with no warnings.

---

### Phase C: status.sh, clean.sh, update.sh Extensions

**Goal**: Supporting scripts correctly handle llama.cpp state.

**Deliverables**:

1. **`status.sh`**: Read `.llm-state` using `grep` (not `source`). If `BACKEND=llama.cpp`, insert `Backend` and `VRAM Tier` rows in the display table after the `Model:` row. Read tier description from `vram-tiers.conf` for the display label.

2. **`clean.sh`**: Add `--profile llamacpp-gpu --profile llamacpp-cpu` to all `docker compose down` invocations. After containers are stopped, delete `$PROJECT_DIR/.llm-state` if it exists.

3. **`update.sh`**: Add `-b BACKEND` and `-V VRAM_TIER` flags (getopts extension). If flags omitted and `.llm-state` exists, read `BACKEND` and `VRAM_TIER` from state file. For `BACKEND=llama.cpp`: call `provision.sh` with all relevant flags (re-provisions with same or new params). For `BACKEND=ollama`: existing behavior unchanged. Update usage string to document new flags.

**Acceptance**: `shellcheck scripts/status.sh scripts/clean.sh scripts/update.sh` exits 0. `status.sh` shows Backend/VRAM Tier rows when state file is present. `clean.sh` deletes `.llm-state` after stopping containers.

---

### Phase D: Documentation

**Goal**: README and example configs updated for llama.cpp.

**Deliverables**:

1. **`README.md`** (or equivalent docs file): Add a "llama.cpp Backend" section covering:
   - Prerequisites (no new requirements — Docker and NVIDIA Container Toolkit already documented).
   - Command examples for all four VRAM tiers.
   - Per-model VRAM tier guidance table (which tier each model requires as a minimum).
   - Note on GGUF auto-download (large files, first-run time).
   - API endpoint (same URL, different model ID format).

2. **`examples/opencode/config.json`**: Add a comment or alternative block showing the llama.cpp model IDs (`glm-4-9b-chat-Q4_K_M`, etc.).

3. **`CLAUDE.md`** (project instructions): Update the Supported models list and Commands section to reflect llama.cpp options.

**Acceptance**: User Story 4 acceptance scenarios pass.

---

## Risk Notes

- **deepseek-v3 GGUF size**: The `DeepSeek-V3-Q4_K_M.gguf` from `unsloth/DeepSeek-V3-GGUF` is hundreds of GB. Download may be impractical for most users. Documentation should note this explicitly and suggest the model is best suited for users with dedicated storage infrastructure. The `min_vram_tier=32gb` in the registry reinforces this.

- **qwen3-coder GGUF verification**: The `Qwen3-Coder-Next-Q4_K_M.gguf` filename and 6 GB VRAM claim should be verified against the actual published HuggingFace files before implementation. If the actual model is larger, the registry `min_vram_gb` and `min_vram_tier` fields should be corrected.

- **llama.cpp image updates**: The `ghcr.io/ggml-org/llama.cpp:server-cuda` tag is a rolling tag (`latest`). `provision.sh` runs `docker compose up --pull always`, ensuring the latest image is pulled on each provision. This is consistent with Ollama behavior.
