# labs-local-llm Development Guidelines

Last updated: 2026-03-25

## Stack

- **Runtime**: Bash 5+, Docker Engine 24+, Docker Compose v2
- **Inference servers**: `ollama/ollama:latest` (default) or `ghcr.io/ggml-org/llama.cpp:server[-cuda]` (llama.cpp backend)
- **API**: OpenAI-compatible on port 11434 (both backends)
- **GPU support**: NVIDIA Container Toolkit (optional — CPU fallback available)
- **Supported models**: `glm-4` (stable), `qwen3-coder` (stable), `deepseek-v3` (stable, high-end GPU), `minimax-m1` (experimental)
- **Backends**: `ollama` (default, pulls models automatically) | `llama.cpp` (GGUF files, `-b llama.cpp`)

## Project Structure

```text
docker-compose.yml          # GPU + CPU profiles for Ollama and llama.cpp
.env.example                # Config template — copy to .env before first run
.gitignore
.llm-state                  # Runtime: active backend/model/tier (auto-created, gitignored)

scripts/
├── provision.sh            # Start a model: -m MODEL [-M gpu|cpu|auto] [-p PORT] [-g GPU_ID] [-b BACKEND] [-V VRAM_TIER]
├── clean.sh                # Stop containers: [--keep-models (default) | --purge-models]
├── update.sh               # Pull latest model + restart: -m MODEL [-b BACKEND] [-V VRAM_TIER]
└── status.sh               # Show running state, model, backend, resources

models/
├── registry.conf           # Model registry (id|ollama_id|min_vram|min_ram|status|gguf_hf_repo|gguf_filename|min_vram_tier)
├── vram-tiers.conf         # llama.cpp VRAM tier configs (tier|ctx_size|n_gpu_layers|batch_size|ubatch_size)
└── minimax-m1.Modelfile    # Ollama Modelfile for MiniMax-M1 GGUF import (experimental)

examples/
├── opencode/config.json    # Copy to ~/.config/opencode/config.json
├── continue/config.json    # Merge into ~/.continue/config.json
└── aider/.aider.conf.yml   # Copy to project root as .aider.conf.yml
```

## Commands

```bash
# Start a model via Ollama (default backend, auto-detects GPU)
./scripts/provision.sh -m glm-4

# Start via llama.cpp (GGUF auto-downloaded, 8gb tier default)
./scripts/provision.sh -m glm-4 -b llama.cpp

# llama.cpp with explicit VRAM tier (8gb | 16gb | 24gb | 32gb)
./scripts/provision.sh -m glm-4 -b llama.cpp -V 16gb

# Force CPU mode / custom port
./scripts/provision.sh -m glm-4 -M cpu -p 11435

# Check running state (shows backend and VRAM tier)
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
- API base: `http://localhost:${LLM_PORT:-11434}/v1` (same for both backends)
- Agent configs must use the exact model `id` returned by `GET /v1/models` — Ollama: `glm4:latest`; llama.cpp: `glm-4-9b-chat-Q4_K_M`
- Adding a new model: add one line to `models/registry.conf` — no script changes needed
- MiniMax-M1 requires a user-provided GGUF at `$MODEL_CACHE_DIR/minimax-m1.gguf` before provisioning (both backends)
- llama.cpp GGUFs (except minimax-m1) are auto-downloaded from HuggingFace on first `provision.sh -b llama.cpp`
- `.llm-state` tracks the active backend/model/tier; created by `provision.sh`, deleted by `clean.sh`

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->

## Active Technologies
- Bash 5+ (shell scripts) + Existing `models/registry.conf`, `ollama/ollama:latest` (002-add-qwen3-coder)
- One line appended to `models/registry.conf` (002-add-qwen3-coder)
- Bash (POSIX-compatible shell scripts, `set -euo pipefail`) + Docker Engine 24+, Docker Compose v2, Ollama (docker image `ollama/ollama:latest`) (003-fix-cache-dir-permissions)
- Local bind-mount via Docker named volume (`model-cache`); path controlled by `MODEL_CACHE_DIR` (003-fix-cache-dir-permissions)
- JSON (config file); Bash 5+ (surrounding tooling unchanged) + OpenCode (external tool, config-driven); Ollama Docker image `ollama/ollama:latest` (004-update-opencode-config)
- File system — `examples/opencode/config.json` (replaces `config.toml`) (004-update-opencode-config)
- Bash 5+ + Docker Engine 24+, Docker Compose v2, `ghcr.io/ggml-org/llama.cpp:server` / `:server-cuda`, NVIDIA Container Toolkit (optional, GPU mode) (005-llama-cpp-backend)
- Bind-mount volume (`model-cache` → `$MODEL_CACHE_DIR`). GGUF files stored alongside existing Ollama model data in the same directory. (005-llama-cpp-backend)

## Recent Changes
- 002-add-qwen3-coder: Added Bash 5+ (shell scripts) + Existing `models/registry.conf`, `ollama/ollama:latest`
