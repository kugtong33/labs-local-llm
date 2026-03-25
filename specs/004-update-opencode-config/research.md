# Research: Update OpenCode Example Configuration

**Feature**: 004-update-opencode-config | **Date**: 2026-03-25

## Findings

### Decision 1: Config file format and name

- **Decision**: Replace `examples/opencode/config.toml` with `examples/opencode/config.json`
- **Rationale**: OpenCode's current schema uses JSON (`$schema: https://opencode.ai/config.json`). TOML is the old format. Keeping the old file name with a `.toml` extension alongside a new `.json` file would confuse users copying the example.
- **Alternatives considered**: Keep the `.toml` file and add a second `.json` file — rejected because it doubles maintenance burden and leaves ambiguity about which file is current.

### Decision 2: Model IDs in the config

- **Decision**: Use Ollama model IDs with `:latest` suffix as returned by `GET /v1/models`
  - qwen3-coder → `qwen3-coder:latest`
  - glm-4 → `glm4:latest`
  - deepseek-v3 → `deepseek-v3:latest`
- **Rationale**: These are the exact values the Ollama server reports after `ollama pull`. The CLAUDE.md already documents this convention. Source: `models/registry.conf` (`ollama_id` column).
- **Alternatives considered**: Use short names without `:latest` — rejected because Ollama appends the tag and `GET /v1/models` always returns the tagged form; using the untagged form may break tool routing in OpenCode.

### Decision 3: Which models to include in the example

- **Decision**: Include qwen3-coder as the active (uncommented) model. Include glm-4 and deepseek-v3 as commented-out model entries with inline notes.
- **Rationale**: qwen3-coder is the model the user was provisioning when this feature was triggered. glm-4 and deepseek-v3 are the other stable models; showing them commented-out lets users switch without hunting for the format.
- **Alternatives considered**: Include only qwen3-coder — rejected because users switching models would have no template to follow.

### Decision 4: Provider npm field

- **Decision**: Include `"npm": "@ai-sdk/openai-compatible"` as provided by the user.
- **Rationale**: This is the exact value from the user-supplied config snippet, indicating OpenCode uses the `@ai-sdk/openai-compatible` package for Ollama compatibility. No research needed — user provided authoritative source.
- **Alternatives considered**: None — user specification is explicit.

### Decision 5: CLAUDE.md update scope

- **Decision**: Update the file path reference in the examples table from `config.toml` to `config.json`.
- **Rationale**: CLAUDE.md documents `examples/opencode/config.toml` as the file to copy. After the rename, the reference would be stale.
- **Alternatives considered**: Leave CLAUDE.md unchanged — rejected because stale documentation is a known source of user confusion.

## No NEEDS CLARIFICATION items remain

All decisions resolved from: user-provided config snippet, `models/registry.conf`, existing `examples/opencode/config.toml`, and `CLAUDE.md`.
