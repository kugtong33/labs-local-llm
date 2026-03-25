# Implementation Plan: Local LLM Coding Assistant Setup

**Branch**: `001-local-llm-coding-setup` | **Date**: 2026-03-25 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-local-llm-coding-setup/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

---

## Summary

Deploy a self-hosted AI coding assistant using **Ollama** as the inference server, running open source models (DeepSeek-V3, GLM-4-9B, MiniMax-M1) in Docker containers with automatic GPU/CPU detection. Four shell scripts (`provision`, `clean`, `update`, `status`) manage the full lifecycle. All agents connect via an OpenAI-compatible API at `http://localhost:11434/v1`.

---

## Technical Context

**Language/Version**: Bash 5+ (shell scripts); Docker Compose v2
**Primary Dependencies**: Docker Engine 24+, Docker Compose v2, Ollama (`ollama/ollama:latest`), NVIDIA Container Toolkit (optional, GPU only)
**Storage**: Docker named volume (`llm-model-cache`) bind-mounted to `$MODEL_CACHE_DIR` on host
**Testing**: Manual smoke tests via `curl`; script validation via `shellcheck`
**Target Platform**: Linux (Ubuntu 22.04+ primary), macOS (secondary via Docker Desktop)
**Project Type**: Infrastructure tooling (Docker Compose + shell scripts)
**Performance Goals**: Server provisioned and responding to API requests within 10 minutes on first run; model switching (clean + provision) within 5 minutes
**Constraints**: Localhost only, single model at a time, NVIDIA GPUs only (AMD out of scope v1), no Windows support without WSL2 (out of scope v1)
**Scale/Scope**: Single developer workstation; one running model instance

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The project constitution (`constitution.md`) is a blank template — no project-specific principles have been ratified. No gate violations to evaluate.

**Post-design re-check**: No constitution constraints exist. Design proceeds without violations.

---

## Project Structure

### Documentation (this feature)

```text
specs/001-local-llm-coding-setup/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/
│   ├── cli.md           # Shell script interface contracts
│   └── api.md           # OpenAI-compatible inference API contract
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
docker-compose.yml        # Main Compose file with GPU/CPU profiles
.env.example              # Template for runtime configuration
.env                      # Local overrides (gitignored)

scripts/
├── provision.sh          # Start a model container (FR-006)
├── clean.sh              # Stop/remove containers (FR-007)
├── update.sh             # Pull latest model + restart (FR-008)
└── status.sh             # Show running state and resources (FR-009)

models/
├── registry.conf         # Supported model registry (id|ollama_id|min_vram|min_ram|status)
└── minimax-m1.Modelfile  # Ollama Modelfile for MiniMax-M1 (not in Ollama library)
```

**Structure Decision**: Flat root-level structure — no `src/` required since the deliverable is configuration files and shell scripts, not application code. The `models/` directory holds metadata and Modelfiles (not actual weight files, which live in the Docker volume).

---

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations. Section not applicable.

---

## Phase 0 Research Summary

All technical unknowns resolved. See [research.md](research.md) for full details.

Key decisions:
1. **Inference server**: Ollama — single image, auto-detects GPU/CPU, OpenAI-compat API at `/v1`, model management built in
2. **Models**: DeepSeek-V3 (stable, high-end GPU), GLM-4-9B (stable, consumer hardware), MiniMax-M1 (experimental, Lightning Attention architecture not fully supported by standard backends)
3. **GPU/CPU strategy**: Compose profiles (`--profile gpu` / `--profile cpu`), wrapping Ollama auto-detection
4. **Volume strategy**: Named Docker volume bind-mounted to `$MODEL_CACHE_DIR`
5. **Port**: 11434 (Ollama default), parameterized via `LLM_PORT`
6. **Agent integration**: OpenAI-compat endpoints — `POST /v1/chat/completions` + `GET /v1/models`

---

## Phase 1 Design Summary

Artifacts generated:

| Artifact | Path | Description |
|---|---|---|
| Data model | [data-model.md](data-model.md) | Entities: Model, InferenceServer, HardwareProfile, ProvisionConfig, ModelVolume, .env schema |
| CLI contract | [contracts/cli.md](contracts/cli.md) | `provision.sh`, `clean.sh`, `update.sh`, `status.sh` — args, exit codes, stdout format |
| API contract | [contracts/api.md](contracts/api.md) | OpenAI-compatible endpoints, streaming SSE format, agent config snippets |
| Quickstart | [quickstart.md](quickstart.md) | Setup guide, agent config examples, troubleshooting |

---

## Implementation Notes

### Docker Compose design

- Two service variants in `docker-compose.yml`: `llm-gpu` (profile: `gpu`) and `llm-cpu` (profile: `cpu`)
- Both use the `ollama/ollama:latest` image via a YAML anchor (`x-llm-base`)
- GPU variant adds `deploy.resources.reservations.devices` with NVIDIA driver
- Named volume `llm-model-cache` mounted to `/root/.ollama` inside the container
- Healthcheck polls Ollama root endpoint (`GET /`) every 30s, 10 retries, 180s start period

### Provision script design

- GPU detection: `nvidia-smi` responsiveness + `docker info | grep nvidia`
- If `--mode auto` (default): runs detection and resolves to `gpu` or `cpu`
- Stops any existing `llm-server` container before starting new one (idempotent)
- Sources `.env` file if present for defaults
- After starting: prints API endpoint, suggests `status.sh` and `docker compose logs -f`

### Model registry design

- `models/registry.conf` is a flat text file: `id|ollama_id|min_vram_gb|min_ram_gb|status`
- All scripts source this file for model validation (FR-012)
- Adding a new model requires only adding a line to this file

### MiniMax-M1 handling

- Not available in Ollama library as of mid-2025 due to Lightning Attention architecture
- `models/minimax-m1.Modelfile` enables import from a user-provided GGUF file
- Provision script detects MiniMax-M1 and runs `ollama create minimax-m1 -f models/minimax-m1.Modelfile` before starting
- Documented as experimental; user must download GGUF manually and place at `$MODEL_CACHE_DIR/minimax-m1.gguf`

### Security considerations

- Server binds to `127.0.0.1` only (not `0.0.0.0`) by default — localhost access only
- `.env` file is gitignored — HF_TOKEN never committed
- No authentication required for localhost use; production exposure is out of scope

---

## Ready for

Run `/speckit.tasks` to generate the implementation task list.
