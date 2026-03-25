# Implementation Plan: Update OpenCode Example Configuration

**Branch**: `004-update-opencode-config` | **Date**: 2026-03-25 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-update-opencode-config/spec.md`

## Summary

Replace `examples/opencode/config.toml` with a `config.json` that uses the current OpenCode JSON schema format. The new config defines an ollama provider entry pointing to the local inference server, with named model entries for qwen3-coder (primary) and the remaining supported models (glm-4, deepseek-v3) as commented-out examples. Update CLAUDE.md to reflect the new file name and format.

## Technical Context

**Language/Version**: JSON (config file); Bash 5+ (surrounding tooling unchanged)
**Primary Dependencies**: OpenCode (external tool, config-driven); Ollama Docker image `ollama/ollama:latest`
**Storage**: File system — `examples/opencode/config.json` (replaces `config.toml`)
**Testing**: Manual — provision a model, copy config to `~/.config/opencode/config.json`, verify OpenCode connects
**Target Platform**: Linux / macOS developer workstation
**Project Type**: Configuration example / documentation update
**Performance Goals**: N/A — static file change
**Constraints**: Config must be valid JSON; provider `baseURL` must match the Ollama API endpoint (`http://localhost:11434/v1`)
**Scale/Scope**: Single file replacement + one CLAUDE.md reference update

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitution is not yet configured for this project (template only). No gates are enforced. The change is minimal scope (one file replaced, one reference updated) — no complexity violations.

## Project Structure

### Documentation (this feature)

```text
specs/004-update-opencode-config/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
examples/
└── opencode/
    └── config.json          # replaces config.toml

CLAUDE.md                    # update file-name reference in examples table
```

**Structure Decision**: No source-code directories involved — this is a pure documentation/config-file update. The single changed file lives in `examples/opencode/`.
