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
-m MODEL   Model name: glm-4 | qwen3-coder | deepseek-v3 | minimax-m1
-M MODE    gpu | cpu | auto (default: auto — detects GPU)
-p PORT    Host port (default: 11434)
-g GPU_ID  NVIDIA device index (default: 0)
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
