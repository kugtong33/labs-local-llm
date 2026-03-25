# Research: Curate Model Registry for Local Hardware

**Branch**: `006-curate-model-registry`
**Date**: 2026-03-25

## Decision 1: codestral-7b → codegemma-7b Substitution

**Decision**: Replace `codestral-7b` with `codegemma-7b` (Google CodeGemma 7B Instruct) in the registry. The registry id becomes `codegemma-7b`; the entry is documented as a substitute for the user-requested "codestral-7b".

**Rationale**: Codestral 7B does not exist. Mistral AI's Codestral model is 22B parameters only (~14 GB VRAM). Codestral Mamba 7B (an SSM-based variant) exists as a research model but has never been published to the Ollama library (confirmed by open GitHub issue #5725, unresolved as of this writing). CodeGemma 7B Instruct is the closest practical substitute: it is 7B, code-focused, available in the Ollama library without license gating, and runs on a 6 GB GPU.

**Alternatives considered**:
- Waiting for Ollama to add codestral-mamba: rejected — no timeline, blocks the feature.
- Using full `codestral` (22B): rejected — requires 14+ GB VRAM, defeats the purpose of targeting old hardware.
- Using `qwen2.5-coder:7b`: viable alternative, but CodeGemma 7B is maintained by Google and has strong code completion benchmarks for its size.

---

## Decision 2: deepseek-coder-lite VRAM Tier

**Decision**: Set `deepseek-coder-lite` (`deepseek-coder-v2:lite`) to `min_vram_gb=10` and `min_vram_tier=16gb`.

**Rationale**: DeepSeek-Coder-V2-Lite is a 16B-parameter MoE model with 2.4B active parameters. Despite the small active parameter count, all 16B parameters must reside in memory for weight loading. At Q4_K_M quantization (~4.5 bits/param), total weight size is approximately 9–10 GB. Adding KV cache for a 2K context requires another 0.5–1 GB, placing total VRAM requirement at 10–11 GB — above the 8 GB tier threshold. A 12 GB GPU (RTX 3060 12GB) handles it comfortably.

**Alternatives considered**:
- Setting min_vram_tier=8gb: rejected — would cause OOM on 8 GB cards and confuse users.
- Using a lighter quantization (Q3_K_M, ~7 GB): possible but compromises quality; Q4_K_M is the project standard.

---

## Decision 3: Final Registry Values for All New Models

All values verified against Ollama library listings and HuggingFace GGUF repositories.

| Registry id | Ollama id | min_vram_gb | min_ram_gb | status | gguf_hf_repo | gguf_filename | min_vram_tier |
|-------------|-----------|-------------|------------|--------|-------------|--------------|---------------|
| `deepseek-coder-lite` | `deepseek-coder-v2:16b-lite-instruct-q4_K_M` | 10 | 12 | stable | `bartowski/DeepSeek-Coder-V2-Lite-Instruct-GGUF` | `DeepSeek-Coder-V2-Lite-Instruct-Q4_K_M.gguf` | 16gb |
| `codellama-7b` | `codellama:7b-instruct` | 4 | 8 | stable | `TheBloke/CodeLlama-7B-Instruct-GGUF` | `CodeLlama-7B-Instruct.Q4_K_M.gguf` | 8gb |
| `codegemma-7b` | `codegemma:7b` | 5 | 10 | stable | `bartowski/codegemma-7b-it-GGUF` | `codegemma-7b-it-Q4_K_M.gguf` | 8gb |
| `starcoder2-3b` | `starcoder2:3b` | 2 | 4 | stable | `second-state/StarCoder2-3B-GGUF` | `starcoder2-3b-Q4_K_M.gguf` | 8gb |
| `starcoder2-7b` | `starcoder2:7b` | 5 | 8 | stable | `second-state/StarCoder2-7B-GGUF` | `starcoder2-7b-Q4_K_M.gguf` | 8gb |
| `starcoder2-15b` | `starcoder2:15b` | 10 | 20 | stable | `second-state/StarCoder2-15B-GGUF` | `starcoder2-15b-Q4_K_M.gguf` | 16gb |

**GGUF filename note**: TheBloke repos use period separators in quantization suffixes (`.Q4_K_M.gguf`); second-state and bartowski repos use underscore separators (`-Q4_K_M.gguf`). Values above reflect each repo's actual convention. Verify against the published repo file list before implementation.

---

## Decision 4: minimax-m1 Special-Case Removal from provision.sh

**Decision**: Remove two minimax-m1-specific blocks from `scripts/provision.sh`: (1) the Ollama GGUF prerequisite check (`if [[ "$MODEL_NAME" == "minimax-m1" && "$BACKEND" == "ollama" ]]`) and (2) the special `ollama create` branch in the model-pull section (`if [[ "$MODEL_NAME" == "minimax-m1" ]]`). The `download_gguf()` function's `local` sentinel handling is preserved — it is generic defensive code usable by any future user-provided GGUF model.

**Rationale**: Once minimax-m1 is removed from the registry, the registry validation at the top of provision.sh will reject `-m minimax-m1` before these blocks are ever reached. Removing the dead code keeps the script clean and reduces maintenance surface.

**Alternatives considered**:
- Keeping the code but commenting it out: rejected — dead code adds confusion; shellcheck may warn.

---

## Decision 5: Supported Model Set After Change

**Removed** (2 models):
- `deepseek-v3` — 80 GB VRAM minimum; GGUF requires hundreds of GB of storage; impractical for any local setup.
- `minimax-m1` — 40 GB VRAM minimum; required manual GGUF download and special Ollama import workflow; experimental status.

**Retained** (2 models, unchanged):
- `glm-4`
- `qwen3-coder`

**Added** (6 models):
- `deepseek-coder-lite`, `codellama-7b`, `codegemma-7b`, `starcoder2-3b`, `starcoder2-7b`, `starcoder2-15b`

**Final supported set** (8 models total): codellama-7b, codegemma-7b, deepseek-coder-lite, glm-4, qwen3-coder, starcoder2-3b, starcoder2-7b, starcoder2-15b.
