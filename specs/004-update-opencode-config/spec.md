# Feature Specification: Update OpenCode Example Configuration

**Feature Branch**: `004-update-opencode-config`
**Created**: 2026-03-25
**Status**: Draft
**Input**: Update opencode examples with new JSON schema format using provider-based ollama configuration and qwen3-coder model

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Configure OpenCode with a Local Model (Priority: P1)

A developer has provisioned a local LLM (e.g., qwen3-coder) and wants to connect OpenCode to it. They copy the example configuration to their OpenCode config directory, and OpenCode immediately connects to the local inference server without any manual edits beyond choosing their model.

**Why this priority**: This is the primary use case — getting OpenCode working with a local model. The example file is the single entry point for all new users of this setup.

**Independent Test**: Copy the example config to `~/.config/opencode/` and launch OpenCode pointing at a running local LLM — the connection should succeed and the selected model should respond.

**Acceptance Scenarios**:

1. **Given** a local LLM is running via `provision.sh`, **When** the user copies the example config and opens OpenCode, **Then** OpenCode connects to the local server and the configured model is available for use.
2. **Given** the example config references qwen3-coder, **When** the user has provisioned qwen3-coder, **Then** OpenCode's model list reflects `qwen3-coder:latest` without further configuration.
3. **Given** the user has not yet provisioned a model, **When** they read the example config, **Then** the inline comments clearly explain which model id to use after each `provision.sh` invocation.

---

### User Story 2 - Switch Between Supported Models (Priority: P2)

A developer switches between models (glm-4, deepseek-v3, qwen3-coder) depending on their task. They want the example config to make the model-switching pattern obvious so they can adapt it without guessing.

**Why this priority**: The project supports multiple models; the example should demonstrate how to add or switch models, reducing friction for multi-model workflows.

**Independent Test**: The example config includes entries (or commented-out entries) for all supported models; a developer can uncomment/edit the desired model and restart OpenCode.

**Acceptance Scenarios**:

1. **Given** the updated example config, **When** a user reads it, **Then** they can identify the model id format for each supported model (glm-4, deepseek-v3, qwen3-coder).
2. **Given** the example config, **When** a developer adds a second model entry for deepseek-v3, **Then** OpenCode offers both models in its interface without additional setup.

---

### Edge Cases

- What happens when the user's OpenCode version does not support the new JSON schema format? The config file must include the `$schema` field so version mismatches surface as a clear validation error rather than silent misconfiguration.
- What if the local server is not running when OpenCode starts? OpenCode should show a connection error; the example config header comment must instruct users to start the server first.
- What if a user still has the old TOML config? The old format and new format are not interchangeable; the example directory should clearly indicate the correct file name and format.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The opencode example configuration file MUST use the current opencode JSON schema format (replacing the previous TOML format).
- **FR-002**: The example MUST include the `$schema` field pointing to the official opencode config schema URL.
- **FR-003**: The example MUST define an ollama provider entry that targets the local inference server endpoint (`http://localhost:11434/v1`).
- **FR-004**: The example MUST include qwen3-coder as a named model entry within the ollama provider, using the model id that matches the value returned by the running server.
- **FR-005**: The example MUST include comments or companion documentation that instruct the user to start the local server before copying the config.
- **FR-006**: The example MUST make clear how to extend the provider's model list to add other supported models (glm-4, deepseek-v3).
- **FR-007**: The CLAUDE.md reference to this example file MUST remain accurate after the update (correct file path and format description).

### Key Entities

- **OpenCode Config File**: The example file in `examples/opencode/` that users copy to their local OpenCode config directory; governs which AI provider and model OpenCode uses.
- **Provider Entry**: A named block within the config that identifies the local inference server, its connection details, and the set of models exposed through it.
- **Model Entry**: A named model within a provider that maps a user-facing model name to the exact id the inference server exposes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer unfamiliar with the new config format can copy the example and have OpenCode connected to a local model within 5 minutes of reading the file.
- **SC-002**: 100% of currently supported models (glm-4, deepseek-v3, qwen3-coder) are either present in the example or referenced in inline comments with the correct model id format.
- **SC-003**: Zero manual edits to the example are required beyond selecting the desired model — all connection parameters are pre-filled with correct defaults.
- **SC-004**: The example file passes validation against the official opencode JSON schema with no errors.

## Assumptions

- OpenCode's current stable release accepts the JSON config format shown in the user-provided snippet; the TOML format is no longer the preferred format.
- The example file will remain in `examples/opencode/` and users copy it manually — no automated installation script is needed for this change.
- The model id for qwen3-coder as returned by the running server is `qwen3-coder:latest`; if this differs, an inline comment in the example will note the pattern to verify via `curl http://localhost:11434/v1/models`.
- Updating the TOML file to JSON constitutes a replacement (same path or a new file name), not an addition of a second format alongside the old one.
- CLAUDE.md references to this example file will be reviewed and updated as part of the same change if the file name or format description changes.
