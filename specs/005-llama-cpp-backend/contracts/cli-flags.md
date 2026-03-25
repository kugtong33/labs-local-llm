# CLI Contract: Script Flag Schemas

**Branch**: `005-llama-cpp-backend`
**Date**: 2026-03-25

## provision.sh

**Usage**: `./scripts/provision.sh -m MODEL [-M MODE] [-p PORT] [-g GPU_ID] [-b BACKEND] [-V VRAM_TIER]`

**Flags** (additions to existing interface shown with `[NEW]`):

| Flag | Arg | Default | Valid values | Description |
|------|-----|---------|--------------|-------------|
| `-m` | MODEL | (required) | registry id | Model to run. Validated against `models/registry.conf`. |
| `-M` | MODE | `auto` | `gpu`, `cpu`, `auto` | Hardware mode. |
| `-p` | PORT | `11434` | integer | Host port to bind. |
| `-g` | GPU_ID | `0` | integer | NVIDIA GPU device index. |
| `-b` | BACKEND | `ollama` | `ollama`, `llama.cpp` | **[NEW]** Inference backend. |
| `-V` | VRAM_TIER | `8gb` | `8gb`, `16gb`, `24gb`, `32gb` | **[NEW]** VRAM tier for llama.cpp. Ignored when `-b ollama`. |
| `-h` | — | — | — | Show help and exit 0. |

**Exit codes** (extended from existing):

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Invalid args / validation error / server did not start |
| `2` | Docker unavailable |
| `3` | Port in use |
| `4` | GPU prerequisites missing |

**Validation rules for new flags**:
- `-b` value must be exactly `ollama` or `llama.cpp` (case-sensitive); any other value → exit 1 with usage error to stderr.
- `-V` value must be exactly one of `8gb`, `16gb`, `24gb`, `32gb`; invalid value → exit 1 listing valid options.
- When `-b llama.cpp` is used and the selected model has `min_vram_tier` > selected `-V` tier: emit a WARNING to stderr but continue (do not block provisioning).
- When `-b llama.cpp` and model's `gguf_hf_repo=local` and GGUF file missing: exit 1 with path of missing file.
- When `-V` is specified without `-b llama.cpp`: the flag is accepted but silently ignored (no error), for forward compatibility.

---

## status.sh

**Usage**: `./scripts/status.sh`

No new flags. Output extended to include Backend and VRAM Tier rows (populated from `.llm-state`).

**Output change** (when llama.cpp is active):

```
╔═══════════════════════════════════════════════════════╗
║  Model:               glm-4-9b-chat-Q4_K_M            ║
║  Backend:             llama.cpp                        ║  ← new row
║  VRAM Tier:           16gb (8K context)               ║  ← new row
║  Port:                11434                            ║
║  Endpoint:            http://localhost:11434/v1        ║
║  Uptime:              12m                              ║
║  Container:           llm-server (running)             ║
║  CPU:                 3.2%                             ║
║  Memory:              6.1GiB / 15.7GiB                ║
║  GPU VRAM:            7842 MiB / 16384 MiB            ║
╚═══════════════════════════════════════════════════════╝
```

When `.llm-state` is absent, Backend defaults to `ollama` for display (backward compatible).

---

## update.sh

**Usage**: `./scripts/update.sh -m MODEL [-M MODE] [-p PORT] [-b BACKEND] [-V VRAM_TIER]`

**Flags** (additions to existing interface):

| Flag | Arg | Default | Valid values | Description |
|------|-----|---------|--------------|-------------|
| `-m` | MODEL | (required) | registry id | Model to update. |
| `-M` | MODE | `auto` | `gpu`, `cpu`, `auto` | Hardware mode after restart. |
| `-p` | PORT | `11434` | integer | Host port. |
| `-b` | BACKEND | (from `.llm-state`) | `ollama`, `llama.cpp` | **[NEW]** Backend. If omitted and state file exists, reads from state. |
| `-V` | VRAM_TIER | (from `.llm-state`) | `8gb`, `16gb`, `24gb`, `32gb` | **[NEW]** VRAM tier. If omitted and state file exists, reads from state. |
| `-h` | — | — | — | Show help and exit 0. |

**Behavior for llama.cpp backend**: Re-provisions the server with the same or specified parameters. GGUF file is not re-downloaded unless `$LLAMACPP_FORCE_DOWNLOAD=1` is set in the environment.

---

## clean.sh

No new flags. Behavior extended:
- When `llm-llamacpp-gpu` or `llm-llamacpp-cpu` profiles are active, `docker compose --profile llamacpp-gpu --profile llamacpp-cpu down ...` is included in the shutdown command.
- `.llm-state` file is deleted after successful shutdown regardless of backend.
- `--purge-models` deletes GGUF files from the model volume in addition to Ollama model data (both are in the same bind-mount directory).
