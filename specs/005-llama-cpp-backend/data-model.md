# Data Model: Add llama.cpp Backend Support

**Branch**: `005-llama-cpp-backend`
**Date**: 2026-03-25

## Entities

### 1. Model Registry Entry (`models/registry.conf`)

A pipe-delimited record that describes a supported model. Extended from 5 fields to 8.

**Fields (in order)**:

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Short name used in scripts (`-m MODEL`). Unique key. |
| `ollama_id` | string | Ollama library identifier (`ollama pull <ollama_id>`). |
| `min_vram_gb` | integer | Minimum NVIDIA VRAM (GB) for GPU inference. |
| `min_ram_gb` | integer | Minimum system RAM (GB) for CPU inference. |
| `status` | enum | `stable` or `experimental`. |
| `gguf_hf_repo` | string | HuggingFace repository path (`owner/repo`). Use `local` for user-provided GGUFs. |
| `gguf_filename` | string | GGUF filename within the HF repo (or local filename in `$MODEL_CACHE_DIR`). |
| `min_vram_tier` | enum | Minimum llama.cpp VRAM tier: `8gb`, `16gb`, `24gb`, `32gb`. |

**Validation rules**:
- `id` must be unique; validated by scripts before use.
- `status` must be exactly `stable` or `experimental`.
- `min_vram_tier` must be one of the four tier values.
- `gguf_hf_repo=local` signals user-provided GGUF; `provision.sh` skips download and only validates local file presence.
- Lines beginning with `#` are comments; blank lines are ignored.

**Current records** (after extension):

```
deepseek-v3|deepseek-v3|80|200|stable|unsloth/DeepSeek-V3-GGUF|DeepSeek-V3-Q4_K_M.gguf|32gb
glm-4|glm4|8|16|stable|bartowski/glm-4-9b-chat-GGUF|glm-4-9b-chat-Q4_K_M.gguf|8gb
minimax-m1|minimax-m1|40|80|experimental|local|minimax-m1.gguf|24gb
qwen3-coder|qwen3-coder|6|12|stable|Qwen/Qwen3-Coder-Next-GGUF|Qwen3-Coder-Next-Q4_K_M.gguf|8gb
```

---

### 2. VRAM Tier Configuration (`models/vram-tiers.conf`)

A new pipe-delimited file defining the four pre-set llama-server parameter bundles.

**Fields (in order)**:

| Field | Type | Description |
|-------|------|-------------|
| `tier` | enum | Tier name: `8gb`, `16gb`, `24gb`, `32gb`. Unique key. |
| `ctx_size` | integer | Context window in tokens (`--ctx-size`). |
| `n_gpu_layers` | integer | GPU layers to offload (`--n-gpu-layers`). 99 = all layers. |
| `batch_size` | integer | Prompt processing batch size (`--batch-size`). |
| `ubatch_size` | integer | Micro-batch size (`--ubatch-size`). |
| `description` | string | Human-readable label for documentation and status output. |

**Validation rules**:
- `tier` must be unique; scripts validate `-V` flag against this column.
- All numeric values must be positive integers.
- Lines beginning with `#` are comments; blank lines are ignored.

**Records**:

```
# Format: tier|ctx_size|n_gpu_layers|batch_size|ubatch_size|description
8gb|2048|99|512|128|Conservative 8 GB — full offload, 2K context
16gb|8192|99|1024|256|Standard 16 GB — full offload, 8K context
24gb|16384|99|2048|512|Performance 24 GB — full offload, 16K context
32gb|32768|99|4096|512|Maximum 32 GB — full offload, 32K context
```

---

### 3. LLM State File (`.llm-state`)

A runtime key=value file written by `provision.sh` and deleted by `clean.sh`. Not committed to git (added to `.gitignore`). Read by `status.sh` and `update.sh`.

**Fields**:

| Key | Type | Description |
|-----|------|-------------|
| `backend` | enum | `ollama` or `llama.cpp`. |
| `vram_tier` | enum | `8gb`, `16gb`, `24gb`, `32gb` (present only when `backend=llama.cpp`). |
| `model` | string | Model `id` from registry (e.g., `glm-4`). |
| `model_file` | string | GGUF filename (present only when `backend=llama.cpp`). |
| `mode` | enum | `gpu` or `cpu`. |
| `port` | integer | The host port the server is bound to. |

**State transitions**:

```
(no file)  →  provision.sh succeeds  →  (.llm-state written)
(.llm-state)  →  clean.sh runs  →  (file deleted, no file)
(.llm-state)  →  provision.sh runs again  →  (.llm-state overwritten)
```

**Example (llama.cpp backend)**:
```
backend=llama.cpp
vram_tier=16gb
model=glm-4
model_file=glm-4-9b-chat-Q4_K_M.gguf
mode=gpu
port=11434
```

**Example (Ollama backend)**:
```
backend=ollama
model=glm-4
mode=gpu
port=11434
```

---

### 4. Docker Compose Service Definitions

Two new services added to `docker-compose.yml` for llama.cpp, complementing the existing Ollama services.

**New services**:

| Service name | Profile | Image | Container |
|--------------|---------|-------|-----------|
| `llm-llamacpp-gpu` | `llamacpp-gpu` | `ghcr.io/ggml-org/llama.cpp:server-cuda` | `llm-server` |
| `llm-llamacpp-cpu` | `llamacpp-cpu` | `ghcr.io/ggml-org/llama.cpp:server` | `llm-server` |

**Environment variables consumed** (set by `provision.sh` before `docker compose up`):

| Variable | Description | Example |
|----------|-------------|---------|
| `LLAMACPP_MODEL_FILE` | GGUF filename relative to model cache mount | `glm-4-9b-chat-Q4_K_M.gguf` |
| `LLAMACPP_CTX_SIZE` | Context window size | `8192` |
| `LLAMACPP_N_GPU_LAYERS` | GPU layers to offload | `99` |
| `LLAMACPP_BATCH_SIZE` | Batch size | `1024` |
| `LLAMACPP_UBATCH_SIZE` | Micro-batch size | `256` |
| `LLM_PORT` | Host port (shared with Ollama) | `11434` |
| `MODEL_CACHE_DIR` | Path to model cache on host | `~/.local/share/llm-models` |
| `GPU_DEVICE_ID` | NVIDIA GPU index (GPU service only) | `0` |

**Port mapping**: `${LLM_PORT:-11434}:8080` — maps the host's configurable port to llama-server's fixed internal port 8080.

**Health check endpoint**: `GET /v1/models` (returns `200 OK` when model is loaded, `503` during loading). Different from Ollama which uses `GET /`.
