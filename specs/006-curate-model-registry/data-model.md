# Data Model: Curate Model Registry for Local Hardware

**Branch**: `006-curate-model-registry`
**Date**: 2026-03-25

## Entity: Model Registry Entry (`models/registry.conf`)

Format unchanged from feature 005: pipe-delimited, 8 columns.

```
id|ollama_id|min_vram_gb|min_ram_gb|status|gguf_hf_repo|gguf_filename|min_vram_tier
```

### Records Removed

| id | Reason |
|----|--------|
| `deepseek-v3` | 80 GB min VRAM; GGUF is hundreds of GB; impractical on any local hardware |
| `minimax-m1` | 40 GB min VRAM; required manual GGUF + special Ollama import; experimental |

### Records Retained (unchanged)

```
glm-4|glm4|8|16|stable|bartowski/glm-4-9b-chat-GGUF|glm-4-9b-chat-Q4_K_M.gguf|8gb
qwen3-coder|qwen3-coder|6|12|stable|Qwen/Qwen3-Coder-GGUF|Qwen3-Coder-Q4_K_M.gguf|8gb
```

### Records Added (6 new)

```
codellama-7b|codellama:7b-instruct|4|8|stable|TheBloke/CodeLlama-7B-Instruct-GGUF|CodeLlama-7B-Instruct.Q4_K_M.gguf|8gb
codegemma-7b|codegemma:7b|5|10|stable|bartowski/codegemma-7b-it-GGUF|codegemma-7b-it-Q4_K_M.gguf|8gb
deepseek-coder-lite|deepseek-coder-v2:16b-lite-instruct-q4_K_M|10|12|stable|bartowski/DeepSeek-Coder-V2-Lite-Instruct-GGUF|DeepSeek-Coder-V2-Lite-Instruct-Q4_K_M.gguf|16gb
starcoder2-3b|starcoder2:3b|2|4|stable|second-state/StarCoder2-3B-GGUF|starcoder2-3b-Q4_K_M.gguf|8gb
starcoder2-7b|starcoder2:7b|5|8|stable|second-state/StarCoder2-7B-GGUF|starcoder2-7b-Q4_K_M.gguf|8gb
starcoder2-15b|starcoder2:15b|10|20|stable|second-state/StarCoder2-15B-GGUF|starcoder2-15b-Q4_K_M.gguf|16gb
```

### Complete registry.conf After Change (8 records, sorted alphabetically by id)

```
codellama-7b|codellama:7b-instruct|4|8|stable|TheBloke/CodeLlama-7B-Instruct-GGUF|CodeLlama-7B-Instruct.Q4_K_M.gguf|8gb
codegemma-7b|codegemma:7b|5|10|stable|bartowski/codegemma-7b-it-GGUF|codegemma-7b-it-Q4_K_M.gguf|8gb
deepseek-coder-lite|deepseek-coder-v2:16b-lite-instruct-q4_K_M|10|12|stable|bartowski/DeepSeek-Coder-V2-Lite-Instruct-GGUF|DeepSeek-Coder-V2-Lite-Instruct-Q4_K_M.gguf|16gb
glm-4|glm4|8|16|stable|bartowski/glm-4-9b-chat-GGUF|glm-4-9b-chat-Q4_K_M.gguf|8gb
qwen3-coder|qwen3-coder|6|12|stable|Qwen/Qwen3-Coder-GGUF|Qwen3-Coder-Q4_K_M.gguf|8gb
starcoder2-3b|starcoder2:3b|2|4|stable|second-state/StarCoder2-3B-GGUF|starcoder2-3b-Q4_K_M.gguf|8gb
starcoder2-7b|starcoder2:7b|5|8|stable|second-state/StarCoder2-7B-GGUF|starcoder2-7b-Q4_K_M.gguf|8gb
starcoder2-15b|starcoder2:15b|10|20|stable|second-state/StarCoder2-15B-GGUF|starcoder2-15b-Q4_K_M.gguf|16gb
```

## Files Changed or Deleted

| File | Change |
|------|--------|
| `models/registry.conf` | Remove 2 records, add 6 records, update header NOTE comment |
| `models/minimax-m1.Modelfile` | **Deleted** — no longer needed |
| `scripts/provision.sh` | Remove 2 minimax-m1-specific code blocks |
| `README.md` | Update models table; remove MiniMax-M1 section; add new models |
| `examples/opencode/config.json` | Remove deepseek-v3 entry; add new model entries |
| `CLAUDE.md` | Update supported models list and commands section |

## Hardware Tier Guide (for documentation)

| Min VRAM | Suitable models |
|----------|----------------|
| 2 GB | starcoder2-3b |
| 4 GB | codellama-7b |
| 5 GB | codegemma-7b, starcoder2-7b |
| 6 GB | qwen3-coder |
| 8 GB | glm-4 |
| 10 GB | deepseek-coder-lite, starcoder2-15b |
