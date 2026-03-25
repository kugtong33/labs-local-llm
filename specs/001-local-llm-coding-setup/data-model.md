# Data Model: Local LLM Coding Assistant Setup

**Feature**: `001-local-llm-coding-setup`
**Date**: 2026-03-25

---

## Entities

### Model

Represents a supported open source LLM that can be provisioned into a container.

| Field | Type | Description | Validation |
|---|---|---|---|
| `id` | string | Short identifier used in scripts and agent config | One of: `deepseek-v3`, `glm-4`, `minimax-m1` |
| `ollama_id` | string | Name as registered in the Ollama library or Modelfile | Non-empty; tag-qualified (e.g., `glm4:latest`) |
| `hf_id` | string | HuggingFace repository identifier | Format: `org/repo` |
| `gguf_available` | boolean | Whether a practical GGUF quantization exists | — |
| `min_vram_gb` | integer | Minimum VRAM required for GPU inference (GB) | > 0 |
| `min_ram_gb` | integer | Minimum system RAM required for CPU inference (GB) | > 0 |
| `status` | enum | Support tier for this setup | One of: `stable`, `experimental` |

**Supported models (initial set)**:

```
id            | ollama_id        | hf_id                      | status
------------- | ---------------- | -------------------------- | ------------
deepseek-v3   | deepseek-v3      | deepseek-ai/DeepSeek-V3    | stable (GPU high-end)
glm-4         | glm4             | THUDM/glm-4-9b-chat        | stable
minimax-m1    | minimax-m1       | MiniMaxAI/MiniMax-M1       | experimental
```

**State transitions**: Models have no runtime state themselves — they are configuration. The *Inference Server* tracks which model is loaded.

---

### Inference Server

Represents a running container instance serving a model's API.

| Field | Type | Description | Validation |
|---|---|---|---|
| `model_id` | string | The model currently loaded | Must be a valid supported Model.id |
| `hardware_mode` | enum | How the container uses compute resources | One of: `gpu`, `cpu` |
| `port` | integer | Host port the API is bound to | 1–65535; not already in use |
| `gpu_device_id` | string | GPU device index (GPU mode only) | Non-negative integer string; default `"0"` |
| `container_name` | string | Docker container name | `llm-server` (fixed) |
| `status` | enum | Runtime state | One of: `starting`, `ready`, `error`, `stopped` |
| `base_url` | string | Derived: `http://localhost:{port}/v1` | — |

**State transitions**:

```
(none) ──provision──► starting ──health-check-passes──► ready
                                ──health-check-fails──►  error
ready  ──clean──►     stopped
ready  ──update──►    starting  (pulls new image, restarts)
error  ──clean──►     stopped
```

---

### Hardware Profile

Represents the compute configuration applied to an Inference Server.

| Field | Type | Description | Validation |
|---|---|---|---|
| `mode` | enum | Hardware mode | One of: `gpu`, `cpu`, `auto` |
| `gpu_device_id` | string | Target GPU device (GPU mode only) | Default `"0"` |
| `resolved_mode` | enum | Actual mode after auto-detection | One of: `gpu`, `cpu` |

**Auto-detection logic**:
- If `mode = auto`: check `nvidia-smi` responsiveness + NVIDIA toolkit Docker registration → resolve to `gpu` or `cpu`
- If `mode = gpu`: validate GPU prerequisites; error if not met
- If `mode = cpu`: skip GPU checks; proceed directly

---

### Provision Configuration

The complete set of parameters defining a requested Inference Server instance.

| Field | Type | Description | Default |
|---|---|---|---|
| `model_id` | string | Model to load | (required) |
| `hardware_profile` | HardwareProfile | Compute configuration | `mode: auto` |
| `port` | integer | Host port | `11434` (Ollama default) |
| `model_cache_dir` | string | Host path for model weight storage | `/opt/llm-models` |
| `hf_token` | string | HuggingFace auth token (for gated models) | `""` (empty) |

---

### Model Volume

Represents the Docker volume holding model weights on the host.

| Field | Type | Description |
|---|---|---|
| `volume_name` | string | Docker volume name (`llm-model-cache`) |
| `host_path` | string | Bind mount path on host (`$MODEL_CACHE_DIR`) |
| `size_estimate_gb` | integer | Approximate disk used (informational) |

**Lifecycle**:
- Created on first `provision.sh` run
- Persists across `clean.sh` (default `--keep-models`)
- Removed only by `clean.sh --purge-models` or `docker volume rm llm-model-cache`

---

## Configuration Files

### `.env` / `.env.example`

Runtime configuration loaded by Docker Compose and shell scripts.

| Key | Type | Default | Description |
|---|---|---|---|
| `MODEL_NAME` | string | `glm4` | Ollama model ID to provision |
| `MODE` | enum | `auto` | Hardware mode: `gpu`, `cpu`, `auto` |
| `LLM_PORT` | integer | `11434` | Host port for the inference server |
| `GPU_DEVICE_ID` | string | `0` | NVIDIA GPU device index |
| `MODEL_CACHE_DIR` | string | `/opt/llm-models` | Host path for model storage |
| `HF_TOKEN` | string | `""` | HuggingFace access token (gated models) |

### `models/registry.conf`

Static file listing all supported models and their metadata (used by scripts for validation).

```
# Format: id|ollama_id|min_vram_gb|min_ram_gb|status
deepseek-v3|deepseek-v3|80|200|stable
glm-4|glm4|8|16|stable
minimax-m1|minimax-m1|40|80|experimental
```

### `models/minimax-m1.Modelfile`

Ollama Modelfile for importing MiniMax-M1 from a local GGUF file (required because it is not in the official Ollama library).

```
FROM /models/gguf/minimax-m1.gguf
TEMPLATE """{{ if .System }}<|im_start|>system
{{ .System }}<|im_end|>
{{ end }}{{ range .Messages }}<|im_start|>{{ .Role }}
{{ .Content }}<|im_end|>
{{ end }}<|im_start|>assistant
"""
PARAMETER stop "<|im_end|>"
```

---

## Validation Rules

| Rule | Description |
|---|---|
| Model must be supported | `model_id` must exist in `models/registry.conf` |
| Port must be available | `lsof -iTCP:$PORT` must return empty before provisioning |
| Docker must be running | `docker info` must succeed before any script runs |
| GPU prerequisites for gpu mode | `nvidia-smi` works + `docker info` shows nvidia runtime |
| MODEL_CACHE_DIR must exist | Directory is created by provision script if missing |
| Single instance enforced | Only one container named `llm-server` runs at a time; provision stops any existing instance first |
