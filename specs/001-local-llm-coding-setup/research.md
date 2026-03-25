# Research: Local LLM Coding Assistant Setup

**Feature**: `001-local-llm-coding-setup`
**Date**: 2026-03-25
**Status**: Complete — all NEEDS CLARIFICATION resolved

---

## Decision 1: Inference Server

**Decision**: **Ollama** as the primary inference server, with **llama.cpp server** available as a secondary option for GGUF-only or edge cases.

**Rationale**:
- Single Docker image (`ollama/ollama`) handles both GPU and CPU automatically — no separate image builds needed
- Auto-detects NVIDIA GPU at runtime; gracefully falls back to CPU if no GPU is present
- Built-in model registry (`ollama pull deepseek-v3`) handles model downloads, versioning, and local caching
- OpenAI-compatible API at `/v1` (since v0.1.24), sufficient for OpenCode, Continue, and Aider
- Simplest Docker Compose setup of all candidates — no `--model` path wiring required

**Alternatives considered**:
- **vLLM**: Best API completeness and GPU performance, but **GPU-only** (no real CPU fallback), which violates FR-004. Excluded as primary.
- **llama.cpp server**: Excellent CPU support and GGUF quantization, but model ID via filename is awkward (requires `--alias` workaround) and lacks Ollama's model management. Kept as secondary for GGUF-only deployments.
- **text-generation-webui (TGI)**: SSE streaming does not reliably send `data: [DONE]`, causing agent hangs. Excluded.
- **LM Studio**: No headless Docker support. Excluded.

---

## Decision 2: Supported Models and Availability

**Decision**: Support **DeepSeek-V3**, **GLM-4-9B**, and **MiniMax-M1** with the following specifics:

| Model | Ollama ID | HuggingFace ID | GGUF Available | Practical CPU Use |
|---|---|---|---|---|
| DeepSeek-V3 | `deepseek-v3` | `deepseek-ai/DeepSeek-V3` | Yes (bartowski, Q2_K~200GB) | Not practical — 671B MoE |
| GLM-4-9B | `glm4` | `THUDM/glm-4-9b-chat` | Yes (Q4_K_M ~5.5GB) | Yes, consumer hardware |
| MiniMax-M1 | manual Modelfile | `MiniMaxAI/MiniMax-M1` | Partial (in progress mid-2025) | Limited |

**Rationale**:
- GLM-4-9B is the most practical model for most developer hardware: 5.5GB GGUF fits in consumer GPU or 16GB RAM
- DeepSeek-V3 requires high-end GPU (A100-class for full weights) or extreme RAM for CPU GGUF; include it but document hardware requirements prominently
- MiniMax-M1 uses Lightning Attention hybrid architecture not fully supported by standard backends; include as experimental with Modelfile-based Ollama approach

**Key gotcha — MiniMax-M1**: Its architecture (linear-attention + MoE) is not natively supported by vLLM or standard llama.cpp as of mid-2025. Ollama support requires a manual GGUF Modelfile. The setup will support it via a custom Modelfile mechanism, but mark it as "experimental" in documentation.

**Key gotcha — GLM-4 chat template**: GLM-4 requires its Jinja2 chat template to be applied. Ollama bundles this correctly when using the official `glm4` library model. Verify template is applied when using custom GGUF imports.

---

## Decision 3: Docker Compose GPU/CPU Strategy

**Decision**: Single `docker-compose.yml` with **Compose profiles** (`--profile gpu` / `--profile cpu`), wrapping an Ollama container that auto-detects the GPU at runtime.

**Rationale**:
- Ollama's single image removes the need for `vllm/vllm-openai` vs. CPU-only image variants
- Compose profiles provide explicit, script-friendly switching without maintaining separate override files
- `deploy.resources` GPU reservation block is the modern standard (Compose v3.8+, preferred over legacy `runtime: nvidia`)

**GPU prerequisite**: NVIDIA Container Toolkit must be installed on the host. The provision script validates this before accepting `--mode gpu`.

**GPU detection logic** (provision script):
1. Check `nvidia-smi` exists and responds
2. Check `docker info | grep nvidia` confirms toolkit registration
3. If both pass → GPU mode. If either fails → warn and fall back to CPU.

**GPU configuration** (key Docker Compose fields):
```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          device_ids: ["${GPU_DEVICE_ID:-0}"]
          capabilities: [gpu]
```

**Alternatives considered**:
- Separate `docker-compose.gpu.yml` + `docker-compose.cpu.yml` override files: more explicit but requires two files and more complex script logic
- `runtime: nvidia` legacy field: works but is deprecated and not compatible with all Compose versions

---

## Decision 4: Volume Strategy for Model Weights

**Decision**: Named Docker volume with a local bind mount to a configurable host path (`$MODEL_CACHE_DIR`, defaulting to `/opt/llm-models`).

**Rationale**:
- Model weights (5GB–200GB+) must persist across container restarts and `docker compose down`
- Named volumes participate in Docker lifecycle, allowing `docker volume rm` for intentional cleanup
- Bind to a predictable host path so users can pre-download models outside Docker
- `HF_HOME` and `HUGGINGFACE_HUB_CACHE` env vars point the inference server to the correct cache path
- For Ollama, the cache is `/root/.ollama`; volume is mounted there

**Clean script safety**: The clean script will default to `--keep-models` (stop containers, preserve volumes). Use `--purge-models` to also remove the model volume. This prevents accidentally deleting hundreds of GB.

**Alternatives considered**:
- Bind mounts directly in Compose: simpler YAML but less portable (path must exist on host before `docker compose up`)

---

## Decision 5: OpenAI-Compatible API Contract

**Decision**: The inference server MUST expose these two endpoints for full agent compatibility:

1. `POST /v1/chat/completions` — streaming (SSE) and non-streaming
2. `GET /v1/models` — model discovery

**Critical details**:
- Streaming responses MUST end with `data: [DONE]` — missing this causes all agents to hang
- The `model.id` returned by `/v1/models` must exactly match the model name used in agent configs
- Ollama default port: **11434**; API at `http://localhost:11434/v1`
- API key: local servers accept any non-empty string (e.g., `"local"`)

**Agent integration approach**:

| Agent | Config mechanism | Key setting |
|---|---|---|
| OpenCode | `~/.config/opencode/config.toml` or env vars | `base_url = "http://localhost:11434/v1"` |
| Continue | `~/.continue/config.json` | `"apiBase": "http://localhost:11434/v1"` |
| Aider | `.aider.conf.yml` or env vars | `openai-api-base: http://localhost:11434/v1` |

The setup will ship a `quickstart.md` with copy-paste config snippets for each agent.

---

## Decision 6: Shell Script Interface

**Decision**: Four scripts in `scripts/` directory:

| Script | Purpose | Key args |
|---|---|---|
| `provision.sh` | Start a model container | `-m MODEL`, `-M gpu\|cpu\|auto`, `-p PORT`, `-g GPU_ID` |
| `clean.sh` | Stop and remove containers | `--keep-models` (default) / `--purge-models` |
| `update.sh` | Pull latest model and restart | `-m MODEL` |
| `status.sh` | Show running containers and resources | (no args) |

All scripts will:
- Validate Docker is installed and daemon is running
- Validate model names against a supported list
- Provide descriptive error messages with suggested fixes
- Print usage help with `-h` / `--help`

---

## Unresolved Items

None. All NEEDS CLARIFICATION items from the spec have been resolved through research.

**Open question (documented, not blocking)**: MiniMax-M1 GGUF community support was still in progress as of mid-2025. The setup will include a placeholder Modelfile template for MiniMax-M1 but mark it experimental until GGUF support stabilizes. Users should verify current availability at `huggingface.co/bartowski` before using this model.
