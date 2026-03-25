# Implementation Plan: Add Qwen3-Coder to Supported Models

**Branch**: `002-add-qwen3-coder` | **Date**: 2026-03-25 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-add-qwen3-coder/spec.md`

---

## Summary

Add Qwen3-Coder to the local LLM setup by appending a single line to `models/registry.conf` and adding a row to the README model table. No script or Docker changes are required — the existing registry-driven design handles the new model automatically.

---

## Technical Context

**Language/Version**: Bash 5+ (shell scripts)
**Primary Dependencies**: Existing `models/registry.conf`, `ollama/ollama:latest`
**Storage**: One line appended to `models/registry.conf`
**Testing**: Manual smoke test — `provision.sh -m qwen3-coder` must start server and respond to `/v1/models`
**Target Platform**: Linux / macOS (same as parent project)
**Project Type**: Infrastructure configuration change
**Performance Goals**: Same as other stable models — server ready within 10 minutes on first provision
**Constraints**: Ollama ID must be verified against the live Ollama library before merge (`ollama search qwen3-coder`)
**Scale/Scope**: Single registry entry + one README row

---

## Constitution Check

Constitution is a blank template — no project-specific principles ratified. No gate violations.

---

## Project Structure

### Documentation (this feature)

```text
specs/002-add-qwen3-coder/
├── plan.md         # This file
├── research.md     # Phase 0 output
├── data-model.md   # Phase 1 output
└── tasks.md        # Phase 2 output (/speckit.tasks)
```

### Files Changed (repository root)

```text
models/
└── registry.conf   # Add one line: qwen3-coder|qwen3-coder|6|12|stable

README.md           # Add Qwen3-Coder row to the model comparison table
```

**Structure Decision**: No new files, no new directories. Purely additive changes to two existing files.

---

## Phase 0 Research Summary

See [research.md](research.md) for full details.

Key decisions:
1. **Ollama ID**: `qwen3-coder` — follows Qwen family naming convention; must be verified with `ollama search qwen3-coder` before merge
2. **Default variant**: 7B (implied by bare Ollama ID), estimated ~6 GB VRAM / ~12 GB RAM
3. **Status**: `stable` — standard transformer architecture, no Modelfile required
4. **Scope**: Registry + README only; zero script changes

---

## Phase 1 Design Summary

| Artifact | Path | Description |
|---|---|---|
| Data model | [data-model.md](data-model.md) | Single registry entry definition with field values |

No contracts generated — no new CLI flags, no new API endpoints.
No quickstart generated — workflow is identical to existing models.

---

## Implementation Notes

### Registry entry

Append to `models/registry.conf`:
```
qwen3-coder|qwen3-coder|6|12|stable
```

The `provision.sh` script reads this file at runtime for:
- Input validation (the `-m` flag)
- Error messages listing supported models
- Resolving the `ollama_id` for `ollama pull`

### README update

Add one row to the model comparison table in `README.md`:

```markdown
| `qwen3-coder` | ~6 GB | ~12 GB | Code-specialized, recommended for coding tasks |
```

### Verification note

Before merging, run `ollama search qwen3-coder` on the target machine. If the Ollama ID differs from `qwen3-coder`, update the second pipe-delimited field in the registry entry.

---

## Ready for

Run `/speckit.tasks` to generate the implementation task list.
