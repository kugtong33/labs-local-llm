# Contract: OpenCode Configuration File

**Feature**: 004-update-opencode-config | **Date**: 2026-03-25
**Interface type**: Configuration file (user-facing example)

## Contract Description

The file `examples/opencode/config.json` is a copy-ready configuration example. Users place it at `~/.config/opencode/config.json` (or the platform-appropriate OpenCode config path) to connect OpenCode to the local Ollama inference server.

## Required Structure

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "<provider-name>": {
      "npm": "<ai-sdk-package>",
      "name": "<display-name>",
      "options": {
        "baseURL": "<inference-api-url>"
      },
      "models": {
        "<model-key>": {
          "name": "<model-id-from-server>"
        }
      }
    }
  }
}
```

## Invariants

1. `$schema` must be present and point to `https://opencode.ai/config.json`.
2. `provider.ollama.options.baseURL` must be `http://localhost:11434/v1` (matches `LLM_PORT` default in `provision.sh`).
3. Each model `name` value must exactly match the `id` field returned by `GET http://localhost:11434/v1/models` after provisioning.
4. The file must be valid JSON (parseable without errors).

## Validated Against

- OpenCode JSON schema (`$schema` URL above)
- Ollama model ids derived from `models/registry.conf` (`ollama_id` column + `:latest` tag)
