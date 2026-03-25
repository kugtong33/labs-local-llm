# Local LLM Coding Assistant

A self-hosted local LLM setup for AI-assisted coding. Runs open source models in Docker with automatic GPU/CPU detection. Connects to OpenCode, Continue, Aider, and other AI coding agents via an OpenAI-compatible API.

## Models

| Model | VRAM (GPU) | RAM (CPU) | Notes |
|---|---|---|---|
| `glm-4` | ~8 GB | ~16 GB | Recommended default — practical on consumer hardware |
| `qwen3-coder` | ~6 GB | ~12 GB | Code-specialized; recommended for coding-focused tasks |
| `deepseek-v3` | ~80 GB | ~200 GB | High-end GPU required |
| `minimax-m1` | ~40 GB | ~80 GB | Experimental — requires manual GGUF download |

## Prerequisites

- **Docker Engine 24+** and **Docker Compose v2** — [Install Docker](https://docs.docker.com/engine/install/)
- **GPU (optional)**: NVIDIA GPU + NVIDIA Container Toolkit
- **Disk space**: 6–200 GB depending on model (downloaded on first provision)
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
-m MODEL      Model name: glm-4 | qwen3-coder | deepseek-v3 | minimax-m1
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
| OpenCode | [`examples/opencode/config.toml`](examples/opencode/config.toml) | Copy to `~/.config/opencode/config.toml` |
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
| `glm-4` | `8gb` | GGUF auto-downloaded from HuggingFace on first run |
| `qwen3-coder` | `8gb` | GGUF auto-downloaded from HuggingFace on first run |
| `minimax-m1` | `24gb` | User must provide GGUF manually (see section below) |
| `deepseek-v3` | `32gb` | ~400 GB GGUF — significant download and storage required |

### API endpoint with llama.cpp

The API endpoint is identical: `http://localhost:11434/v1`. The model `id` returned by `GET /v1/models` differs from Ollama:

| Model | Ollama id | llama.cpp id |
|-------|-----------|--------------|
| `glm-4` | `glm4:latest` | `glm-4-9b-chat-Q4_K_M` |
| `qwen3-coder` | `qwen3-coder:latest` | `Qwen3-Coder-Q4_K_M` |
| `deepseek-v3` | `deepseek-v3:latest` | `DeepSeek-V3-Q4_K_M` |
| `minimax-m1` | `minimax-m1:latest` | `minimax-m1` |

Update your agent config's model name to match when switching backends.

---

## MiniMax-M1 (Experimental)

MiniMax-M1 requires a manual GGUF download (not in Ollama library):

```bash
# 1. Download a GGUF from HuggingFace (e.g., bartowski/MiniMax-M1-GGUF)
# 2. Place the file in MODEL_CACHE_DIR (default: ~/.local/share/llm-models)
cp minimax-m1.Q4_K_M.gguf ~/.local/share/llm-models/minimax-m1.gguf
# 3. Provision
./scripts/provision.sh -m minimax-m1
```

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
