# Implementation Plan: Curate Model Registry for Local Hardware

**Branch**: `006-curate-model-registry` | **Date**: 2026-03-25 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/006-curate-model-registry/spec.md`

## Summary

Remove two impractical large models (deepseek-v3, minimax-m1) from the registry and add six code-focused models that run on consumer GPUs with 2–10 GB VRAM. This is primarily a data-change feature: update `models/registry.conf`, delete `models/minimax-m1.Modelfile`, remove two dead code blocks from `scripts/provision.sh`, and refresh documentation. No new scripting logic is required — the existing generic registry-driven provisioning handles all new models automatically.

The user-requested `codestral-7b` does not exist in Ollama; `codegemma-7b` (Google CodeGemma 7B Instruct) is substituted as the nearest available 7B code model.

## Technical Context

**Language/Version**: Bash 5+
**Primary Dependencies**: Docker Engine 24+, Docker Compose v2, Ollama library (model pull), `ghcr.io/ggml-org/llama.cpp:server[-cuda]` (llama.cpp GGUF)
**Storage**: `models/registry.conf` (pipe-delimited text), `models/minimax-m1.Modelfile` (deleted)
**Testing**: `shellcheck` (zero-warning requirement); manual smoke tests per quickstart.md checklist
**Target Platform**: Linux — unchanged from existing project
**Project Type**: CLI toolset (Bash scripts + Docker Compose)
**Performance Goals**: No new performance requirements. New models must start within the existing 3-minute server-ready timeout.
**Constraints**: Registry format (8-column pipe-delimited) is fixed. No new flags, no new scripts. `shellcheck` must pass on all modified scripts.
**Scale/Scope**: 8 registry entries total after change (net +4). 1 file deleted.

## Constitution Check

Constitution file contains only template placeholders — no project-specific principles defined. No gates to enforce.

## Project Structure

### Documentation (this feature)

```text
specs/006-curate-model-registry/
├── plan.md          # This file
├── spec.md          # Feature specification
├── research.md      # Model lookup decisions, codestral substitution, GGUF values
├── data-model.md    # Complete registry delta (removed/retained/added records)
└── quickstart.md    # Files changed, provision.sh blocks to remove, test checklist
```

### Source Code (repository root)

```text
models/
├── registry.conf              # -2 records, +6 records, updated header comment
└── minimax-m1.Modelfile       # DELETED

scripts/
└── provision.sh               # Remove 2 minimax-m1-specific blocks; shellcheck

README.md                      # Update models table; remove MiniMax-M1 section; add new models
examples/opencode/config.json  # Remove deepseek-v3; add 6 new model entries
CLAUDE.md                      # Update supported models list
```

**Structure Decision**: Single project (existing layout). All changes are in-place edits or file deletion. No new files at repository root.

## Complexity Tracking

No constitution violations. No complexity justification required.

---

## Implementation Phases

### Phase A: Registry & Script Cleanup

**Goal**: The registry accurately reflects the 8-model set. minimax-m1.Modelfile is gone. provision.sh is clean.

**Deliverables**:

1. **`models/registry.conf`**:
   - Remove the `deepseek-v3` and `minimax-m1` records.
   - Add 6 new records using exact values from `specs/006-curate-model-registry/data-model.md` §"Records Added".
   - Update the header `NOTE` comment: remove old size warnings; add a note about the `codestral-7b → codegemma-7b` substitution.
   - Sort entries alphabetically by id for readability.

2. **`models/minimax-m1.Modelfile`** — delete this file (`git rm`).

3. **`scripts/provision.sh`** — remove two minimax-m1-specific blocks as described in `specs/006-curate-model-registry/quickstart.md` §"provision.sh blocks to remove":
   - Block 1: Ollama GGUF prerequisite check (`if [[ "$MODEL_NAME" == "minimax-m1" && "$BACKEND" == "ollama" ]]`).
   - Block 2: Special `ollama create` branch; the `else` branch (`docker exec llm-server ollama pull "$OLLAMA_ID"`) becomes unconditional.
   - Run `shellcheck scripts/provision.sh` — must pass with 0 warnings.

**Acceptance**: `./scripts/provision.sh -m deepseek-v3` and `-m minimax-m1` both exit 1. `shellcheck` passes.

---

### Phase B: Documentation

**Goal**: README, example configs, and CLAUDE.md reflect the 8-model lineup with no trace of removed models.

**Deliverables**:

1. **`README.md`**:
   - Replace models table: 8 rows (codellama-7b, codegemma-7b, deepseek-coder-lite, glm-4, qwen3-coder, starcoder2-3b, starcoder2-7b, starcoder2-15b) with VRAM/RAM columns and a note that codegemma-7b substitutes the unavailable codestral-7b.
   - Delete the `## MiniMax-M1 (Experimental)` section.
   - Update the llama.cpp Backend section: per-model minimum tier table and model ID mapping table to reflect 8 current models.
   - Add a hardware selection guide: which models suit 4 GB / 6 GB / 8 GB / 10 GB+ GPUs.

2. **`examples/opencode/config.json`**:
   - Remove `deepseek-v3` model entry.
   - Add 6 new model entries under the `ollama` provider.
   - Update the `_llama_cpp_ids` comment block with IDs for the new models.

3. **`CLAUDE.md`**:
   - Update the Supported models list to the 8 current models.
   - Note the codegemma-7b substitution.
   - Remove minimax-m1 references from Key Conventions.

**Acceptance**: README models table shows exactly 8 rows. No `deepseek-v3` or `minimax-m1` in user-facing text. User with 6 GB GPU can identify 3+ suitable models from README alone.
