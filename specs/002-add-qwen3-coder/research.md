# Research: Add Qwen3-Coder to Supported Models

**Feature**: `002-add-qwen3-coder`
**Date**: 2026-03-25
**Status**: Complete

---

## Decision 1: Ollama Identifier

**Decision**: Use `qwen3-coder` as the Ollama pull identifier (e.g., `ollama pull qwen3-coder`).

**Rationale**: Qwen3-Coder was released after the August 2025 knowledge cutoff and is not confirmed in training data. However, the Ollama naming convention for the Qwen family is consistent: `qwen2.5-coder` for Qwen2.5-Coder, `qwen3` for Qwen3 base. The expected Ollama library ID for Qwen3-Coder follows this pattern as `qwen3-coder`.

**Action required before merging**: Verify the exact Ollama ID by running `ollama search qwen3-coder` or checking `https://ollama.com/library/qwen3-coder`. If the ID differs, update the `ollama_id` field in `models/registry.conf` accordingly.

**Alternatives considered**:
- `qwen3-coder:7b` (tag-qualified) — Ollama accepts both bare name and tag; bare name pulls the recommended default tag. Using the bare name is consistent with other entries in registry.conf (`deepseek-v3`, `glm4`).

---

## Decision 2: Default Size Variant

**Decision**: Register the model with the 7B variant as the implied default (bare `qwen3-coder` pull), which targets ~6 GB VRAM / ~12 GB RAM.

**Rationale**: The Qwen2.5-Coder 7B is the most widely deployed consumer-hardware coding model in the Qwen family, requiring ~4–5 GB VRAM at Q4 quantization and ~8 GB RAM for CPU inference. Qwen3-Coder 7B is expected to have comparable requirements. This makes it accessible on standard developer laptops with 8–16 GB RAM.

**Alternatives considered**:
- 14B variant: Better code quality but requires ~10–12 GB VRAM / ~20 GB RAM — excludes many consumer GPUs.
- 32B variant: High-end GPU required; out of scope for the default entry.

**Note**: Users can run larger variants by overriding the Ollama tag manually (e.g., `ollama pull qwen3-coder:14b` inside the container) — this is outside the scope of the registry entry.

---

## Decision 3: Stability Status

**Decision**: Register as `stable`.

**Rationale**: The Qwen model family uses standard dense transformer architecture, which is fully supported by llama.cpp and Ollama with no custom Modelfile or special handling. No experimental flags, custom attention mechanisms, or GGUF conversion issues are expected (unlike MiniMax-M1's Lightning Attention). The Qwen2.5-Coder series has been production-stable with Ollama, and Qwen3-Coder is expected to follow the same pattern.

**Alternatives considered**:
- `experimental`: Would be appropriate if architecture is non-standard. Downgrading to experimental post-merge is easy if issues arise.

---

## Decision 4: No Script or Tooling Changes Required

**Decision**: Implementation is registry + README only. No changes to `provision.sh`, `clean.sh`, `update.sh`, `status.sh`, or `docker-compose.yml`.

**Rationale**: The existing registry-driven design in `provision.sh` already handles any model listed in `models/registry.conf`. The `ollama pull $OLLAMA_ID` path in provision.sh works for any standard Ollama library model. Qwen3-Coder requires no Modelfile (unlike MiniMax-M1), no custom Docker config, and no new script flags.

---

## Unresolved Items

- **Ollama ID must be verified** before merging: run `ollama search qwen3-coder` on the target machine to confirm the exact identifier. The registry entry uses `qwen3-coder` as the best-guess default.
- **Hardware specs are estimates**: VRAM (~6 GB) and RAM (~12 GB) are based on Qwen2.5-Coder 7B as a comparable reference. Verify against the model card once published.
