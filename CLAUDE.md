# labs-local-llm Development Guidelines

Last updated: 2026-03-25

## Stack

- **Runtime**: Bash 5+, Docker Engine 24+, Docker Compose v2
- **Inference server**: `ollama/ollama:latest` (OpenAI-compatible API on port 11434)
- **GPU support**: NVIDIA Container Toolkit (optional — CPU fallback available)
- **Supported models**: `glm-4` (stable), `deepseek-v3` (stable, high-end GPU), `minimax-m1` (experimental)

## Project Structure

```text
docker-compose.yml          # GPU + CPU Compose profiles (ollama/ollama:latest)
.env.example                # Config template — copy to .env before first run
.gitignore

scripts/
├── provision.sh            # Start a model: -m MODEL [-M gpu|cpu|auto] [-p PORT] [-g GPU_ID]
├── clean.sh                # Stop containers: [--keep-models (default) | --purge-models]
├── update.sh               # Pull latest model + restart: -m MODEL
└── status.sh               # Show running state, model, resources

models/
├── registry.conf           # Supported model registry (id|ollama_id|min_vram|min_ram|status)
└── minimax-m1.Modelfile    # Ollama Modelfile for MiniMax-M1 GGUF import (experimental)

examples/
├── opencode/config.toml    # Copy to ~/.config/opencode/config.toml
├── continue/config.json    # Merge into ~/.continue/config.json
└── aider/.aider.conf.yml   # Copy to project root as .aider.conf.yml
```

## Commands

```bash
# Start a model (auto-detects GPU, falls back to CPU)
./scripts/provision.sh -m glm-4

# Force CPU mode / custom port
./scripts/provision.sh -m glm-4 -M cpu -p 11435

# Check running state
./scripts/status.sh

# Update model to latest version
./scripts/update.sh -m glm-4

# Stop server (keep downloaded weights)
./scripts/clean.sh

# Stop server AND delete all model weights
./scripts/clean.sh --purge-models
```

## Code Style

- All scripts use `set -euo pipefail`
- Argument parsing via `getopts` (short flags) or `case "$arg"` (long flags)
- Errors go to stderr (`>&2`), info/success to stdout
- Exit codes: 0 success, 1 invalid args/validation, 2 Docker unavailable, 3 port in use, 4 GPU prerequisites missing
- Model names validated against `models/registry.conf` in every script
- `shellcheck` must pass with no warnings on all scripts in `scripts/`

## Key Conventions

- The Docker container is always named `llm-server`
- The model volume is always named `llm-model-cache`
- Ollama API base: `http://localhost:${LLM_PORT:-11434}/v1`
- Agent configs must use the exact model `id` returned by `GET /v1/models` (e.g., `glm4:latest`)
- Adding a new model: add one line to `models/registry.conf` — no script changes needed
- MiniMax-M1 requires a user-provided GGUF at `$MODEL_CACHE_DIR/minimax-m1.gguf` before provisioning

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
