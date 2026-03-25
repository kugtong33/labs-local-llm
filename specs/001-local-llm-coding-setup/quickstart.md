# Quickstart: Local LLM Coding Assistant

**Feature**: `001-local-llm-coding-setup`
**Date**: 2026-03-25

Get a local LLM running for AI-assisted coding in under 10 minutes.

---

## Prerequisites

- Docker Engine 24+ and Docker Compose v2
- (GPU) NVIDIA GPU + NVIDIA Container Toolkit installed
- Internet access (to pull Docker image and model weights on first run)
- 16 GB RAM minimum (GLM-4); 200 GB+ for DeepSeek-V3

### Install NVIDIA Container Toolkit (GPU only)

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

---

## Step 1: Start the LLM Server

```bash
# Clone this repo and enter it
git clone <repo-url> labs-local-llm && cd labs-local-llm

# Make scripts executable
chmod +x scripts/*.sh

# Start GLM-4 (recommended for most hardware — ~5.5 GB, GPU auto-detected)
./scripts/provision.sh -m glm-4

# Or: force CPU mode
./scripts/provision.sh -m glm-4 -M cpu

# Or: run DeepSeek-V3 (requires high-end GPU, ~80 GB VRAM)
./scripts/provision.sh -m deepseek-v3
```

The server takes 1–3 minutes to download the model on first run. Check progress with:
```bash
docker compose logs -f
```

When ready, you will see:
```
SUCCESS: LLM server is ready
  API endpoint:  http://localhost:11434/v1
```

Verify with:
```bash
curl http://localhost:11434/v1/models
```

---

## Step 2: Connect Your Coding Agent

### OpenCode

Edit `~/.config/opencode/config.toml`:

```toml
[model]
provider = "openai"
model = "glm4:latest"
base_url = "http://localhost:11434/v1"
api_key = "local"
```

Then run `opencode` in your project directory.

### Continue (VS Code)

Edit `~/.continue/config.json` and add to the `models` array:

```json
{
  "title": "Local GLM-4",
  "provider": "openai",
  "model": "glm4:latest",
  "apiBase": "http://localhost:11434/v1",
  "apiKey": "local"
}
```

Reload VS Code and select "Local GLM-4" from the Continue model picker.

### Aider

In your project directory, create `.aider.conf.yml`:

```yaml
model: openai/glm4:latest
openai-api-base: http://localhost:11434/v1
openai-api-key: local
```

Then run `aider`.

---

## Step 3: Check Status

```bash
./scripts/status.sh
```

---

## Common Operations

```bash
# Switch to DeepSeek-V3 (stops current model, starts new one)
./scripts/provision.sh -m deepseek-v3

# Update GLM-4 to the latest version
./scripts/update.sh -m glm-4

# Stop the server (keeps downloaded models)
./scripts/clean.sh

# Stop the server AND remove all downloaded model weights
./scripts/clean.sh --purge-models

# Use a different port (e.g., if 11434 is taken)
./scripts/provision.sh -m glm-4 -p 8080
```

---

## Model Comparison

| Model | VRAM (GPU) | RAM (CPU) | Best for | Status |
|---|---|---|---|---|
| GLM-4-9B | ~8 GB | ~16 GB | General coding, chat, consumer hardware | Stable |
| DeepSeek-V3 | ~80 GB | ~200 GB | Complex reasoning, large codebases | Stable (high-end GPU required) |
| MiniMax-M1 | ~40 GB | ~80 GB | Experimental | Experimental |

---

## Troubleshooting

**Server won't start — GPU not detected**
```bash
# Verify NVIDIA toolkit is registered with Docker
docker info | grep -i nvidia
# Should show: Runtimes: nvidia
```

**Agent can't connect**
```bash
# Check the server is running
./scripts/status.sh
# Verify the model ID matches what the agent is configured to use
curl http://localhost:11434/v1/models | python3 -m json.tool
```

**Out of memory error during model load**
- Switch to CPU mode: `./scripts/provision.sh -m glm-4 -M cpu`
- Use a smaller model: GLM-4-9B requires far less memory than DeepSeek-V3
- Increase Docker memory limit in Docker Desktop settings

**Port already in use**
```bash
./scripts/provision.sh -m glm-4 -p 11435
# Then update agent config to use http://localhost:11435/v1
```
