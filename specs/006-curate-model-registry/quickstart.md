# Developer Quickstart: Curate Model Registry for Local Hardware

**Branch**: `006-curate-model-registry`
**Date**: 2026-03-25

## What changes

This is a data-change feature with minimal scripting. The registry gains 6 models and loses 2; one Modelfile is deleted; two dead code blocks are removed from provision.sh; documentation is updated.

## Files changed

```
models/registry.conf           # -2 records (deepseek-v3, minimax-m1), +6 new records
models/minimax-m1.Modelfile    # DELETED
scripts/provision.sh           # Remove 2 minimax-m1 special-case blocks
README.md                      # Update models table + remove MiniMax-M1 section
examples/opencode/config.json  # Remove deepseek-v3; add new models
CLAUDE.md                      # Update supported models list
```

## provision.sh blocks to remove

### Block 1 — Ollama GGUF prerequisite check (~line 200)
```bash
# Remove this entire block:
if [[ "$MODEL_NAME" == "minimax-m1" && "$BACKEND" == "ollama" ]]; then
  GGUF_PATH="$MODEL_CACHE_DIR/minimax-m1.gguf"
  if [[ ! -f "$GGUF_PATH" ]]; then
    echo "ERROR: MiniMax-M1 GGUF file not found at $GGUF_PATH" >&2
    ...
    exit 1
  fi
fi
```

### Block 2 — Special ollama create branch (~line 360)
```bash
# Remove the minimax-m1 branch, keep only the else branch:
if [[ "$MODEL_NAME" == "minimax-m1" ]]; then
  echo "INFO: [EXPERIMENTAL] Importing MiniMax-M1 from GGUF file..."
  docker cp "$MODELFILE_DIR/minimax-m1.Modelfile" llm-server:/tmp/minimax-m1.Modelfile
  docker exec llm-server ollama create minimax-m1 -f /tmp/minimax-m1.Modelfile
else
  docker exec llm-server ollama pull "$OLLAMA_ID"  # ← keep this line
fi
```
After removal the pull section becomes simply:
```bash
docker exec llm-server ollama pull "$OLLAMA_ID"
```

## Key substitution note

The user requested `codestral-7b`. **Codestral 7B does not exist in the Ollama library.** This feature adds `codegemma-7b` (Google CodeGemma 7B Instruct) as a 7B code model in the same VRAM range. This substitution must be documented in the README and CLAUDE.md.

## Testing checklist

- [ ] `./scripts/provision.sh -m deepseek-v3` exits 1 with "Unsupported model" message
- [ ] `./scripts/provision.sh -m minimax-m1` exits 1 with "Unsupported model" message
- [ ] `./scripts/provision.sh -h` shows none of the removed models; shows all 8 current models in error messages
- [ ] `./scripts/provision.sh -m starcoder2-3b` (Ollama backend) — server starts, API responds
- [ ] `./scripts/provision.sh -m codellama-7b` (Ollama backend) — server starts, API responds
- [ ] `./scripts/provision.sh -m starcoder2-3b -b llama.cpp` — GGUF downloaded, server starts
- [ ] `shellcheck scripts/provision.sh` passes with 0 warnings after block removal
- [ ] README models table shows exactly 8 models with no mention of deepseek-v3 or minimax-m1
- [ ] `models/minimax-m1.Modelfile` no longer exists in the repository
