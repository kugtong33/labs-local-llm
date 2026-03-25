# Developer Quickstart: llama.cpp Backend

**Branch**: `005-llama-cpp-backend`
**Date**: 2026-03-25

## What changes

This feature adds a second inference backend (`llama.cpp`) alongside the existing Ollama backend. Most of the change is in `provision.sh` and `docker-compose.yml`. The other scripts (`status.sh`, `clean.sh`, `update.sh`) get minor extensions.

## Files changed

```
docker-compose.yml           # +2 services: llm-llamacpp-gpu, llm-llamacpp-cpu
models/registry.conf         # +3 columns: gguf_hf_repo, gguf_filename, min_vram_tier
models/vram-tiers.conf       # NEW: 4 VRAM tier configs
scripts/provision.sh         # +2 flags: -b BACKEND, -V VRAM_TIER; GGUF download logic
scripts/status.sh            # +Backend and VRAM Tier rows in output
scripts/clean.sh             # +llamacpp profiles in compose down; delete .llm-state
scripts/update.sh            # +reads .llm-state; re-provisions for llama.cpp
.gitignore                   # +.llm-state
```

## End-to-end flow for llama.cpp provisioning

1. User runs `./scripts/provision.sh -m glm-4 -b llama.cpp -V 16gb`
2. `provision.sh` validates flags and model registry entry.
3. Reads `models/vram-tiers.conf` for the `16gb` row → sets `LLAMACPP_CTX_SIZE=8192`, etc.
4. Checks if `$MODEL_CACHE_DIR/glm-4-9b-chat-Q4_K_M.gguf` exists.
   - If not: downloads via `curl -L -C - -o $MODEL_CACHE_DIR/glm-4-9b-chat-Q4_K_M.gguf https://huggingface.co/bartowski/glm-4-9b-chat-GGUF/resolve/main/glm-4-9b-chat-Q4_K_M.gguf`
5. Stops any existing `llm-server` container.
6. Exports env vars: `LLAMACPP_MODEL_FILE`, `LLAMACPP_CTX_SIZE`, `LLAMACPP_N_GPU_LAYERS`, etc.
7. Runs `docker compose --profile llamacpp-gpu up -d --pull always` (or `llamacpp-cpu` for CPU mode).
8. Polls `GET http://localhost:11434/v1/models` until `200 OK` (model loaded) or timeout.
9. Writes `.llm-state`.
10. Prints success summary.

## Key implementation notes for contributors

### getopts extension in provision.sh
The existing `while getopts "m:M:p:g:h" opt` loop must be extended to `"m:M:p:g:b:V:h"`. The `-V` flag (uppercase) is safe — no existing flag uses it.

### GGUF download helper function
Add a `download_gguf()` function to `provision.sh`. Uses `curl -L -C - --progress-bar`. Aborts with exit 1 if `curl` is unavailable. Shows download progress to stdout.

### Startup health check branch
The existing health check loop uses `curl -sf "http://localhost:${LLM_PORT}/"`. For llama.cpp, this must be `curl -sf "http://localhost:${LLM_PORT}/v1/models"`. Branch on `$BACKEND`:
```bash
if [[ "$BACKEND" == "llama.cpp" ]]; then
  curl -sf "http://localhost:${LLM_PORT}/v1/models" &>/dev/null
else
  curl -sf "http://localhost:${LLM_PORT}/" &>/dev/null
fi
```

### State file writing
Write `.llm-state` immediately before the success output block in `provision.sh`. The file must be written atomically (write to a temp file, then `mv`).

### clean.sh profile list
Change `docker compose --profile gpu --profile cpu down` to `docker compose --profile gpu --profile cpu --profile llamacpp-gpu --profile llamacpp-cpu down`. This is backward-compatible — unused profiles are a no-op.

### status.sh state file reading
Source `.llm-state` safely: check if file exists first, then use `grep` to extract values (not `source`, to avoid executing arbitrary content).
```bash
if [[ -f "$PROJECT_DIR/.llm-state" ]]; then
  BACKEND="$(grep '^backend=' "$PROJECT_DIR/.llm-state" | cut -d= -f2)"
  VRAM_TIER="$(grep '^vram_tier=' "$PROJECT_DIR/.llm-state" | cut -d= -f2)"
fi
```

## Testing checklist

- [ ] `./scripts/provision.sh -m glm-4 -b llama.cpp` starts server, API responds
- [ ] `./scripts/provision.sh -m glm-4` (no -b flag) still uses Ollama — backward compat
- [ ] `./scripts/provision.sh -m glm-4 -b llama.cpp -V 16gb` applies 16GB tier params
- [ ] `./scripts/provision.sh -m glm-4 -b llama.cpp -V 48gb` exits 1 with valid tier list
- [ ] `./scripts/provision.sh -m glm-4 -b unknown` exits 1 with usage error
- [ ] `./scripts/status.sh` shows Backend and VRAM Tier rows when llama.cpp is active
- [ ] `./scripts/clean.sh` stops llama.cpp container and deletes `.llm-state`
- [ ] `shellcheck scripts/provision.sh scripts/clean.sh scripts/status.sh scripts/update.sh` passes with 0 warnings
- [ ] GGUF download skipped when file already present in cache
