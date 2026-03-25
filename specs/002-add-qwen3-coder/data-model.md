# Data Model: Add Qwen3-Coder to Supported Models

**Feature**: `002-add-qwen3-coder`
**Date**: 2026-03-25

---

## New Registry Entry

One line added to `models/registry.conf`:

| Field | Value | Notes |
|---|---|---|
| `id` | `qwen3-coder` | Short name used in scripts: `./scripts/provision.sh -m qwen3-coder` |
| `ollama_id` | `qwen3-coder` | Ollama library pull identifier — verify with `ollama search qwen3-coder` |
| `min_vram_gb` | `6` | Estimated for 7B default variant at Q4 quantization |
| `min_ram_gb` | `12` | Estimated for 7B default variant on CPU |
| `status` | `stable` | Standard transformer architecture, fully supported by Ollama |

**Resulting registry line**:
```
qwen3-coder|qwen3-coder|6|12|stable
```

---

## Impact on Existing Entities

No existing entities change. The registry entry is additive only.

- `provision.sh` reads `models/registry.conf` at runtime — no redeployment needed after registry update.
- The error message listing supported models is dynamically generated from the registry — `qwen3-coder` will automatically appear once the line is added.
