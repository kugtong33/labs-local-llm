# Research: Add llama.cpp Backend Support

**Branch**: `005-llama-cpp-backend`
**Date**: 2026-03-25

## Decision 1: Docker Image Selection

**Decision**: Use `ghcr.io/ggml-org/llama.cpp:server` (CPU) and `ghcr.io/ggml-org/llama.cpp:server-cuda` (GPU/NVIDIA).

**Rationale**: Official upstream images maintained by the ggml-org. The `:server` tag ships only the `llama-server` binary, keeping image size minimal. The `-cuda` suffix enables NVIDIA GPU support, matching the project's existing NVIDIA Container Toolkit requirement. AMD ROCm (`:server-rocm`) is out of scope for v1.

**Alternatives considered**:
- Building a custom image from source: rejected — more maintenance burden, no benefit for this use case.
- Using `:full` image tag: rejected — includes unnecessary model conversion utilities, larger image.

---

## Decision 2: Container Port Mapping

**Decision**: llama-server binds to port `8080` inside the container. Map to `${LLM_PORT:-11434}:8080` in Docker Compose, identical to the Ollama port mapping scheme.

**Rationale**: Preserves the same external port (11434) used by Ollama, so existing client configurations (opencode, continue, aider) work unchanged. Users who specify a custom port with `-p` get the same behavior.

**Alternatives considered**:
- Exposing llama-server on port 11434 inside the container: not how the upstream image works; would require a custom entrypoint wrapper.

---

## Decision 3: Health Check Endpoint

**Decision**: Use `/v1/models` as the readiness probe for llama-server (returning `200 OK` when model is loaded, `503` during loading). The `/health` endpoint is a liveness-only probe (returns `200 OK` immediately before model loading completes) and MUST NOT be used as the startup readiness check.

**Rationale**: `provision.sh` waits for the server to be fully ready (model loaded) before declaring success. Using `/health` would produce a false positive. `/v1/models` only returns `200` when the model is actually serving requests.

**Alternatives considered**:
- `/health`: rejected — returns `200` immediately, before model loading completes.

---

## Decision 4: VRAM Tier Parameter Values

**Decision**: Four static parameter sets, stored in `models/vram-tiers.conf`.

| Tier | ctx_size | n_gpu_layers | batch_size | ubatch_size |
|------|----------|--------------|------------|-------------|
| 8gb  | 2048     | 99           | 512        | 128         |
| 16gb | 8192     | 99           | 1024       | 256         |
| 24gb | 16384    | 99           | 2048       | 512         |
| 32gb | 32768    | 99           | 4096       | 512         |

`n_gpu_layers=99` means "attempt to offload 99 layers" which effectively offloads all layers for any model with fewer than 99 layers (all supported models). For models that do not fit fully in VRAM at the selected context size, llama-server automatically falls back to partial CPU offloading.

**Rationale for 8gb ctx=2048**: Conservative to ensure the KV cache fits within 8 GB alongside the model weights. For glm-4 (9B, Q4_K_M ~5.5 GB), a 2048-token KV cache adds ~0.5 GB, fitting within 8 GB total. For qwen3-coder (6 GB min_vram), 2048 context leaves adequate headroom.

**Rationale for n_gpu_layers=99 even in 8gb tier**: Full GPU offload is preferable to partial when the model fits (glm-4 Q4_K_M fits in 8 GB). For models that don't fit, llama-server handles partial offloading automatically.

**Alternatives considered**:
- Per-model tier configs: rejected — combinatorial complexity, unnecessary for v1. Tier configs are intentionally model-agnostic.
- Runtime auto-tuning: rejected — requires additional tooling; static configs are simpler and more predictable.

---

## Decision 5: GGUF Model Sources

**Decision**: Extend `models/registry.conf` with `gguf_hf_repo` and `gguf_filename` fields. `provision.sh` downloads GGUF from Hugging Face using `curl -L -C -` (resumable) if not already present.

| Model | HF Repo | Filename | Min Tier |
|-------|---------|----------|----------|
| glm-4 | `bartowski/glm-4-9b-chat-GGUF` | `glm-4-9b-chat-Q4_K_M.gguf` | 8gb |
| qwen3-coder | `Qwen/Qwen3-Coder-Next-GGUF` | `Qwen3-Coder-Next-Q4_K_M.gguf` | 8gb |
| deepseek-v3 | `unsloth/DeepSeek-V3-GGUF` | `DeepSeek-V3-Q4_K_M.gguf` | 32gb |
| minimax-m1 | `local` | `minimax-m1.gguf` | 24gb |

**Note on minimax-m1**: GGUF is user-provided (existing behavior). The `gguf_hf_repo=local` sentinel causes `provision.sh` to skip downloading and only validate the local file.

**Note on qwen3-coder**: The 6 GB min_vram in the registry may be aspirational. The `Qwen3-Coder-Next` model size is not fully confirmed at time of writing. The Q4_K_M GGUF filename will be verified against the actual published files before implementation. The registry `min_vram_tier` for qwen3-coder is set to `8gb` but actual requirements may be higher.

**Note on deepseek-v3**: The Q4_K_M GGUF for DeepSeek-V3 (671B MoE) is multi-part and extremely large (~400 GB). The `DeepSeek-V3-Q4_K_M.gguf` designation assumes the unsloth single-file quantization. In practice, users will likely need to provide this model via a custom path. The registry records the canonical source; documentation will note the storage requirements.

**Rationale for curl download**: `curl` is universally available in the target environments. Resumable download (`-C -`) is important for large GGUF files. `huggingface-cli` would require Python/pip setup, adding a prerequisite.

**Alternatives considered**:
- Separate llama.cpp registry file: rejected — duplicates model metadata, harder to maintain.
- Docker container for downloading (e.g., huggingface-cli in a container): rejected — overkill for file download; `curl` suffices.

---

## Decision 6: Backend State Tracking

**Decision**: Write a `.llm-state` file (key=value format) at project root on every successful `provision.sh` run. Delete it in `clean.sh`. `status.sh` and `update.sh` read it to determine active backend and VRAM tier.

**File format**:
```
backend=llama.cpp
vram_tier=16gb
model=glm-4
model_file=glm-4-9b-chat-Q4_K_M.gguf
mode=gpu
port=11434
```

**Rationale**: Allows `status.sh` to display backend/tier without inspecting container internals (image name parsing is fragile). Allows `update.sh` to re-provision with the same parameters. The file is gitignored (runtime state).

**Alternatives considered**:
- Inspect Docker image name to infer backend: fragile, depends on exact image naming.
- Docker labels on the running container: works but requires `docker inspect` and label encoding.

---

## Decision 7: Docker Compose Service Structure

**Decision**: Add two new top-level services to `docker-compose.yml`: `llm-llamacpp-gpu` (profile `llamacpp-gpu`) and `llm-llamacpp-cpu` (profile `llamacpp-cpu`). Both use `container_name: llm-server` for compatibility with all existing scripts. Parameterize llama-server flags via environment variables: `LLAMACPP_MODEL_FILE`, `LLAMACPP_CTX_SIZE`, `LLAMACPP_N_GPU_LAYERS`, `LLAMACPP_BATCH_SIZE`, `LLAMACPP_UBATCH_SIZE`.

**Rationale**: Profile-based activation mirrors the existing Ollama pattern (`--profile gpu` / `--profile cpu`). Using environment variables for VRAM tier parameters avoids duplicating compose services per tier — `provision.sh` simply exports the right values before running `docker compose up`.

**Alternatives considered**:
- A separate `docker-compose-llamacpp.yml` file: rejected — splits infrastructure, complicates `clean.sh`/`status.sh`.
- Hardcoded command args per tier: rejected — would require 8 services (4 tiers × 2 hardware modes).

---

## Decision 8: update.sh behavior for llama.cpp

**Decision**: For llama.cpp backend, `update.sh` re-provisions from scratch: stops the current server, re-downloads the GGUF (curl will skip if file is unchanged, unless `--force` is passed), and restarts with the same parameters from `.llm-state`. No native "pull latest" equivalent exists for GGUF files.

**Rationale**: GGUF files are static artifacts; unlike Ollama, there is no model registry to query for updates. Re-provisioning is the correct semantic. The `.llm-state` file provides all parameters needed.

**Alternatives considered**:
- Forcing re-download on every update: rejected — large files, wasteful if unchanged.
- Comparing file checksums against HF: possible enhancement for v2; out of scope for v1.
