# Local LLM Coding Assistant

A self-hosted local LLM setup for AI-assisted coding. Runs open source models in Docker with automatic GPU/CPU detection. Connects to OpenCode, Continue, Aider, and other AI coding agents via an OpenAI-compatible API.

## Models

All models are code-focused and run on consumer GPUs. Pick based on your available VRAM.

| Model | VRAM (GPU) | RAM (CPU) | Notes |
|---|---|---|---|
| `starcoder2-3b` | ~2 GB | ~4 GB | Smallest model — runs on almost any GPU |
| `codellama-7b` | ~4 GB | ~8 GB | Meta CodeLlama 7B Instruct |
| `codegemma-7b` | ~5 GB | ~10 GB | Google CodeGemma 7B Instruct (substitutes unavailable codestral-7b) |
| `starcoder2-7b` | ~5 GB | ~8 GB | BigCode StarCoder2 7B |
| `qwen3-coder` | ~6 GB | ~12 GB | Qwen3 Coder — strong code reasoning |
| `glm-4` | ~8 GB | ~16 GB | General-purpose; reliable on 8 GB GPUs |
| `deepseek-coder-lite` | ~10 GB | ~12 GB | DeepSeek-Coder-V2-Lite 16B MoE (2.4B active params) |
| `starcoder2-15b` | ~10 GB | ~20 GB | BigCode StarCoder2 15B — best code quality in the set |

### Hardware selection guide

| GPU VRAM | Recommended models |
|---|---|
| 2–4 GB | `starcoder2-3b` |
| 4–6 GB | `codellama-7b`, `codegemma-7b`, `starcoder2-7b` |
| 6–8 GB | `qwen3-coder`, `glm-4` |
| 10 GB+ | `deepseek-coder-lite`, `starcoder2-15b` |

## Prerequisites

- **Docker Engine 24+** and **Docker Compose v2** — [Install Docker](https://docs.docker.com/engine/install/)
- **GPU (optional)**: NVIDIA GPU + NVIDIA Container Toolkit
- **Disk space**: 2–20 GB depending on model (downloaded on first provision)
- **Internet**: Required on first run to pull Docker image and model weights

### Install NVIDIA Container Toolkit (GPU only, Ubuntu/Debian)

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

## Quick Start

```bash
# 1. Clone and prepare
git clone <repo-url> labs-local-llm && cd labs-local-llm
chmod +x scripts/*.sh

# 2. Configure (optional — defaults work for most setups)
cp .env.example .env

# 3. Start GLM-4 (GPU auto-detected, falls back to CPU)
./scripts/provision.sh -m glm-4

# 4. Verify
curl http://localhost:11434/v1/models
```

## Scripts

| Script | Purpose | Example |
|---|---|---|
| `provision.sh` | Start a model container | `./scripts/provision.sh -m glm-4 -M gpu` |
| `clean.sh` | Stop containers (keeps models) | `./scripts/clean.sh` |
| `update.sh` | Pull latest model + restart | `./scripts/update.sh -m glm-4` |
| `status.sh` | Show running state | `./scripts/status.sh` |

### provision.sh options

```
-m MODEL      Model name: see Models table above for supported values
-M MODE       gpu | cpu | auto (default: auto — detects GPU)
-p PORT       Host port (default: 11434)
-g GPU_ID     NVIDIA device index (default: 0)
-b BACKEND    ollama | llama.cpp (default: ollama)
-V VRAM_TIER  8gb | 16gb | 24gb | 32gb (default: 8gb, llama.cpp only)
```

### clean.sh options

```
--keep-models    Stop containers, preserve downloaded weights (default)
--purge-models   Stop containers AND delete all model weights (irreversible)
```

## Connect Your AI Coding Agent

All agents connect to: `http://localhost:11434/v1`

The model name used in agent config must match what `GET /v1/models` returns (e.g., `glm4:latest`).

Ready-to-use config files are in [`examples/`](examples/):

| Agent | Config file | Instructions |
|---|---|---|
| OpenCode | [`examples/opencode/config.json`](examples/opencode/config.json) | Copy to `~/.config/opencode/config.json` |
| Continue | [`examples/continue/config.json`](examples/continue/config.json) | Merge into `~/.continue/config.json` |
| Aider | [`examples/aider/.aider.conf.yml`](examples/aider/.aider.conf.yml) | Copy to project root as `.aider.conf.yml` |

## llama.cpp Backend

In addition to Ollama, you can run models via [llama.cpp](https://github.com/ggml-org/llama.cpp) for direct GGUF inference. Use the `-b llama.cpp` flag. The same OpenAI-compatible API is available at the same endpoint.

### VRAM tier selection

The `-V` flag selects a pre-set configuration tuned for your GPU memory budget. The 8 GB tier is the default.

| Tier | Context | Use when |
|------|---------|----------|
| `8gb` (default) | 2 K tokens | 8 GB GPU — conservative, broad hardware support |
| `16gb` | 8 K tokens | 16 GB GPU — standard performance |
| `24gb` | 16 K tokens | 24 GB GPU — large context workloads |
| `32gb` | 32 K tokens | 32 GB GPU — maximum context / throughput |

### Quick start with llama.cpp

```bash
# Start glm-4 via llama.cpp on an 8 GB GPU (GGUF auto-downloaded)
./scripts/provision.sh -m glm-4 -b llama.cpp

# 16 GB GPU — unlock 8 K context window
./scripts/provision.sh -m glm-4 -b llama.cpp -V 16gb

# 24 GB GPU
./scripts/provision.sh -m glm-4 -b llama.cpp -V 24gb

# 32 GB GPU — maximum context
./scripts/provision.sh -m glm-4 -b llama.cpp -V 32gb

# Force CPU mode
./scripts/provision.sh -m glm-4 -b llama.cpp -M cpu
```

### Per-model minimum VRAM tier

| Model | Min tier | Notes |
|-------|----------|-------|
| `starcoder2-3b` | `8gb` | GGUF auto-downloaded from HuggingFace on first run |
| `codellama-7b` | `8gb` | GGUF auto-downloaded from HuggingFace on first run |
| `codegemma-7b` | `8gb` | GGUF auto-downloaded from HuggingFace on first run |
| `starcoder2-7b` | `8gb` | GGUF auto-downloaded from HuggingFace on first run |
| `qwen3-coder` | `8gb` | GGUF auto-downloaded from HuggingFace on first run |
| `glm-4` | `8gb` | GGUF auto-downloaded from HuggingFace on first run |
| `deepseek-coder-lite` | `16gb` | 16B MoE model — all weights must be resident (~10 GB) |
| `starcoder2-15b` | `16gb` | GGUF auto-downloaded from HuggingFace on first run |

### API endpoint with llama.cpp

The API endpoint is identical: `http://localhost:11434/v1`. The model `id` returned by `GET /v1/models` differs from Ollama:

| Model | Ollama id | llama.cpp id |
|-------|-----------|--------------|
| `starcoder2-3b` | `starcoder2:3b` | `starcoder2-3b-Q4_K_M` |
| `codellama-7b` | `codellama:7b-instruct` | `CodeLlama-7B-Instruct.Q4_K_M` |
| `codegemma-7b` | `codegemma:7b` | `codegemma-7b-it-Q4_K_M` |
| `starcoder2-7b` | `starcoder2:7b` | `starcoder2-7b-Q4_K_M` |
| `qwen3-coder` | `qwen3-coder:latest` | `Qwen3-Coder-Q4_K_M` |
| `glm-4` | `glm4:latest` | `glm-4-9b-chat-Q4_K_M` |
| `deepseek-coder-lite` | `deepseek-coder-v2:16b-lite-instruct-q4_K_M` | `DeepSeek-Coder-V2-Lite-Instruct-Q4_K_M` |
| `starcoder2-15b` | `starcoder2:15b` | `starcoder2-15b-Q4_K_M` |

Update your agent config's model name to match when switching backends.

---

## Troubleshooting

**GPU not detected**
```bash
docker info | grep -i nvidia   # should show: Runtimes: nvidia
nvidia-smi                     # should print GPU table
```

**Agent can't connect / wrong model name**
```bash
# Check the exact model id to use in agent config
curl http://localhost:11434/v1/models | python3 -m json.tool
```

**Port already in use**
```bash
./scripts/provision.sh -m glm-4 -p 11435
# Update agent config to use http://localhost:11435/v1
```

**Out of memory**
- Switch to CPU mode: `./scripts/provision.sh -m glm-4 -M cpu`
- Use GLM-4 instead of larger models

**View server logs**
```bash
docker compose logs -f
```
