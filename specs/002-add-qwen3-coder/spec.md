# Feature Specification: Add Qwen3-Coder to Supported Models

**Feature Branch**: `002-add-qwen3-coder`
**Created**: 2026-03-25
**Status**: Draft
**Input**: User description: "add qwen3-coder to the supported models"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Provision Qwen3-Coder Like Any Other Model (Priority: P1)

As a developer, I want to run Qwen3-Coder locally using the same provisioning command I use for other models, so that I have a code-specialized LLM available without any extra setup steps.

**Why this priority**: This is the entire scope of the feature — the model must be provisionable via the existing `provision.sh` script with no changes to the workflow. Everything else follows from this.

**Independent Test**: Can be fully tested by running `./scripts/provision.sh -m qwen3-coder` and verifying the server starts and responds to a code-completion request. Delivers immediate value as an additional locally-hosted coding model.

**Acceptance Scenarios**:

1. **Given** the setup is installed, **When** the user runs `./scripts/provision.sh -m qwen3-coder`, **Then** the Qwen3-Coder model downloads, starts, and the inference server becomes available on the configured port.
2. **Given** Qwen3-Coder is running, **When** a client calls the model listing endpoint, **Then** the response includes a Qwen3-Coder model entry.
3. **Given** Qwen3-Coder is running, **When** a code-completion prompt is sent, **Then** a valid response is returned in the expected format.
4. **Given** the user runs `./scripts/provision.sh -m qwen3-coder -M cpu`, **Then** the model starts in CPU-only mode.
5. **Given** the user runs `./scripts/provision.sh -m qwen3-coder -M gpu`, **Then** the model starts with GPU acceleration.

---

### User Story 2 - See Qwen3-Coder Listed as a Supported Option (Priority: P2)

As a developer, I want Qwen3-Coder to appear in the model registry and documentation so that I know it is an available, supported choice alongside the other models.

**Why this priority**: Discoverability matters — a model that works but is not documented or validated in the registry is not truly supported. This story ensures the model is a first-class entry in the setup.

**Independent Test**: Can be fully tested by inspecting `models/registry.conf` for the Qwen3-Coder entry and running `./scripts/provision.sh -m bad-name` to confirm the error message lists `qwen3-coder` among the supported options.

**Acceptance Scenarios**:

1. **Given** the registry is updated, **When** the user runs `./scripts/provision.sh -m bad-model`, **Then** the error message listing supported models includes `qwen3-coder`.
2. **Given** the README or model table is updated, **When** a user reads the documentation, **Then** Qwen3-Coder appears with its hardware requirements and status.

---

### Edge Cases

- What happens if the user specifies `qwen3-coder` before the model has been pulled — does the provision script handle the initial download gracefully?
- What happens if the host machine does not meet the minimum VRAM or RAM requirements for Qwen3-Coder?
- What if a newer or larger Qwen3-Coder variant (e.g., 14B, 32B) is preferred — can the user override the default size?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The model registry MUST include a `qwen3-coder` entry with its Ollama identifier, minimum VRAM, minimum RAM, and status.
- **FR-002**: The provision script MUST accept `qwen3-coder` as a valid `-m` value and start the model's inference server successfully.
- **FR-003**: The provision script's error message for invalid model names MUST include `qwen3-coder` in the list of supported options.
- **FR-004**: Qwen3-Coder MUST be provisionable in both GPU and CPU modes using the existing `--mode` flag.
- **FR-005**: The project README MUST list Qwen3-Coder in the model comparison table with its hardware requirements and status.

### Key Entities

- **Model Registry Entry**: A single line in `models/registry.conf` defining `qwen3-coder`'s id, Ollama identifier, minimum VRAM, minimum RAM, and stability status.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can provision Qwen3-Coder using a single command (`./scripts/provision.sh -m qwen3-coder`) with no additional steps beyond what any other supported model requires.
- **SC-002**: The model responds to a code-completion request within the same workflow as all other supported models — no custom tooling or workarounds needed.
- **SC-003**: `qwen3-coder` appears in the supported model list produced by the provision script's validation error and in the README model table.

## Assumptions

- Qwen3-Coder is available in the Ollama model library and can be pulled via `ollama pull qwen3-coder`.
- The default size variant registered is the 7B parameter version, which is practical on consumer hardware (~6 GB VRAM / ~12 GB RAM); users can pull larger variants manually using Ollama tags.
- Qwen3-Coder is treated as `stable` status — it uses standard transformer architecture fully supported by Ollama without any custom Modelfile.
- No changes to the provisioning scripts are required; only the registry and documentation need updating.
- AI coding agent configs (OpenCode, Continue, Aider) do not need updating — they connect to whatever model is currently running via the existing endpoint.
