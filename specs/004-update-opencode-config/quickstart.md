# Quickstart: OpenCode + Local LLM

**Feature**: 004-update-opencode-config

## What changes

`examples/opencode/config.toml` → `examples/opencode/config.json`

The format moves from TOML to JSON and adopts the new OpenCode provider schema. The connection details and model IDs remain the same.

## Steps

1. **Start the local LLM server**

   ```bash
   ./scripts/provision.sh -m qwen3-coder
   ```

2. **Copy the example config**

   ```bash
   mkdir -p ~/.config/opencode
   cp examples/opencode/config.json ~/.config/opencode/config.json
   ```

3. **Verify the model ID** (optional but recommended)

   ```bash
   curl -s http://localhost:11434/v1/models | jq '.data[].id'
   # Should print: "qwen3-coder:latest"
   ```

   The `name` field in the config must match this value exactly.

4. **Open OpenCode** — it will connect to the local server automatically.

## Switching models

To use glm-4 instead:

1. Provision the model: `./scripts/provision.sh -m glm-4`
2. Edit `~/.config/opencode/config.json` — uncomment the `glm-4` model entry and comment out (or remove) `qwen3-coder`.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| OpenCode shows "connection refused" | Server not running | Run `provision.sh` first |
| Model not found | Wrong model id in config | Run `curl .../v1/models` and match the `id` exactly |
| Schema validation error | Old OpenCode version | Upgrade OpenCode to a release that supports the JSON config schema |
