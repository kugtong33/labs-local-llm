# Data Model: OpenCode Config Structure

**Feature**: 004-update-opencode-config | **Date**: 2026-03-25

## Config File Entity

**File**: `examples/opencode/config.json`
**Consumed by**: OpenCode (external tool)
**Schema**: `https://opencode.ai/config.json`

### Top-level fields

| Field     | Type   | Required | Description                                        |
|-----------|--------|----------|----------------------------------------------------|
| `$schema` | string | yes      | URL of the OpenCode JSON schema for validation     |
| `provider`| object | yes      | Map of named provider entries                      |

### Provider entry (`provider.<name>`)

| Field     | Type   | Required | Description                                                    |
|-----------|--------|----------|----------------------------------------------------------------|
| `npm`     | string | yes      | npm package used for provider compatibility                    |
| `name`    | string | yes      | Human-readable provider label shown in OpenCode UI             |
| `options` | object | yes      | Provider connection options (e.g., `baseURL`)                  |
| `models`  | object | yes      | Map of named model entries available through this provider     |

### Provider options (`provider.<name>.options`)

| Field     | Type   | Required | Description                                                   |
|-----------|--------|----------|---------------------------------------------------------------|
| `baseURL` | string | yes      | Base URL of the OpenAI-compatible inference API               |

### Model entry (`provider.<name>.models.<model-id>`)

| Field  | Type   | Required | Description                                              |
|--------|--------|----------|----------------------------------------------------------|
| `name` | string | yes      | Exact model id as returned by `GET <baseURL>/models`     |

## Model ID Reference

Derived from `models/registry.conf` (`ollama_id` column + Ollama `:latest` tag convention):

| Script `-m` flag | Ollama pull id   | OpenCode model `name` value |
|------------------|------------------|-----------------------------|
| `qwen3-coder`    | `qwen3-coder`    | `qwen3-coder:latest`        |
| `glm-4`          | `glm4`           | `glm4:latest`               |
| `deepseek-v3`    | `deepseek-v3`    | `deepseek-v3:latest`        |
| `minimax-m1`     | `minimax-m1`     | `minimax-m1:latest`         |
