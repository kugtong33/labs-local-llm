# Contract: Registry File Formats

**Branch**: `005-llama-cpp-backend`
**Date**: 2026-03-25

## models/registry.conf

**Format**: Pipe-delimited (`|`), one record per non-comment line. Comments start with `#`. Blank lines ignored.

**Column schema** (8 columns, extended from existing 5):

```
id|ollama_id|min_vram_gb|min_ram_gb|status|gguf_hf_repo|gguf_filename|min_vram_tier
```

| Col | Name | Type | Constraints |
|-----|------|------|-------------|
| 1 | `id` | string | Unique. Used as `-m MODEL` arg. No spaces. |
| 2 | `ollama_id` | string | Ollama pull identifier. |
| 3 | `min_vram_gb` | integer | GPU VRAM minimum in GB. |
| 4 | `min_ram_gb` | integer | System RAM minimum in GB. |
| 5 | `status` | enum | `stable` or `experimental`. |
| 6 | `gguf_hf_repo` | string | HuggingFace `owner/repo`. Use `local` for user-provided. |
| 7 | `gguf_filename` | string | GGUF file name (no path). File placed in `$MODEL_CACHE_DIR`. |
| 8 | `min_vram_tier` | enum | `8gb`, `16gb`, `24gb`, or `32gb`. |

**Backward compatibility**: Scripts that parse only columns 1–5 (existing Ollama logic) remain unaffected. New llama.cpp logic reads columns 6–8 only when `-b llama.cpp` is active.

**Adding a new model**: Append one line following the schema. No script changes required.

---

## models/vram-tiers.conf (new file)

**Format**: Pipe-delimited, one record per non-comment line.

**Column schema** (6 columns):

```
tier|ctx_size|n_gpu_layers|batch_size|ubatch_size|description
```

| Col | Name | Type | Constraints |
|-----|------|------|-------------|
| 1 | `tier` | enum | Unique. One of `8gb`, `16gb`, `24gb`, `32gb`. |
| 2 | `ctx_size` | integer | Positive. Context window tokens. |
| 3 | `n_gpu_layers` | integer | Positive. 99 = offload all layers. |
| 4 | `batch_size` | integer | Positive. |
| 5 | `ubatch_size` | integer | Positive. Must be ≤ `batch_size`. |
| 6 | `description` | string | Human-readable label. Used in `status.sh` output. |

**Fixed records** (not user-editable in v1):

```
# Format: tier|ctx_size|n_gpu_layers|batch_size|ubatch_size|description
8gb|2048|99|512|128|Conservative 8 GB — full offload, 2K context
16gb|8192|99|1024|256|Standard 16 GB — full offload, 8K context
24gb|16384|99|2048|512|Performance 24 GB — full offload, 16K context
32gb|32768|99|4096|512|Maximum 32 GB — full offload, 32K context
```

---

## .llm-state (runtime, gitignored)

**Format**: `key=value`, one pair per line. No quotes. No spaces around `=`.

**Keys**:

| Key | Present when | Values |
|-----|-------------|--------|
| `backend` | Always | `ollama`, `llama.cpp` |
| `model` | Always | Registry `id` (e.g., `glm-4`) |
| `mode` | Always | `gpu`, `cpu` |
| `port` | Always | Port number as integer string |
| `vram_tier` | `backend=llama.cpp` only | `8gb`, `16gb`, `24gb`, `32gb` |
| `model_file` | `backend=llama.cpp` only | GGUF filename (no path) |

**Written by**: `provision.sh` (on success).
**Deleted by**: `clean.sh`.
**Read by**: `status.sh`, `update.sh`.
**Git**: Added to `.gitignore`.
