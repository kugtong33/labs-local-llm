# Feature Specification: Local LLM Coding Assistant Setup

**Feature Branch**: `001-local-llm-coding-setup`
**Created**: 2026-03-25
**Status**: Draft
**Input**: User description: "build a local llm setup, I want to have a personal llm that supports my coding needs - use models that are open source and can be run locally (GLM-4, MiniMax-M1, DeepSeek-V3) - run them on a docker setup, with GPU support, CPU only option is provided - opencode and other open source ai coding agents can connect to these local llms - provide shell scripts that simplify provisioning, cleaning, updating, and managing the local docker llm setup"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Spin Up a Local LLM for Coding (Priority: P1)

As a developer, I want to start a local LLM inference server on my machine so that I can use an AI coding assistant without relying on external cloud services or API keys.

**Why this priority**: This is the foundational capability — nothing else works without a running local LLM. A developer must be able to go from zero to a running model with a single command.

**Independent Test**: Can be fully tested by running the provision script and verifying that a model serves responses to a standard chat completion request. Delivers immediate value as a self-hosted AI coding tool.

**Acceptance Scenarios**:

1. **Given** the user has Docker installed and runs the provision script, **When** the script completes, **Then** an LLM inference server is running and accessible on a local port, responding to chat completion requests.
2. **Given** a GPU is available on the host, **When** the user provisions with the GPU option, **Then** the model runs with GPU acceleration.
3. **Given** no GPU is available, **When** the user provisions with the CPU option, **Then** the model runs on CPU without error.
4. **Given** the user selects a specific model (e.g., DeepSeek-V3), **When** the server starts, **Then** that model is loaded and identified in server metadata.

---

### User Story 2 - Connect an AI Coding Agent to the Local LLM (Priority: P2)

As a developer using OpenCode or another open source AI coding agent, I want to point my agent at the local LLM so that I can use it as the AI backend instead of a paid cloud provider.

**Why this priority**: The primary purpose of the setup is to support coding workflows. An AI coding agent must be able to connect seamlessly, making this second only to the server being up.

**Independent Test**: Can be fully tested by configuring OpenCode's model endpoint to the local server URL and performing a code completion or chat request. Delivers value as a fully self-hosted coding assistant.

**Acceptance Scenarios**:

1. **Given** a local LLM server is running, **When** an AI coding agent is configured to use its endpoint, **Then** the agent receives valid responses compatible with its expected protocol.
2. **Given** the server is running, **When** a client queries the available models, **Then** the response lists the loaded model(s) by name.
3. **Given** an AI agent sends a code-focused prompt, **When** the local LLM responds, **Then** the response is returned in the format the agent expects (OpenAI-compatible chat completion format).

---

### User Story 3 - Manage the LLM Setup via Shell Scripts (Priority: P3)

As a developer, I want simple shell commands to provision, update, clean, and check status so that I can maintain my local LLM environment without memorizing Docker commands.

**Why this priority**: Operational simplicity is essential for long-term usability. Without management scripts, the setup is fragile and hard to maintain, but the server can still function without them initially.

**Independent Test**: Can be fully tested by running each script (provision, clean, update, status) and confirming the expected Docker state after each operation. Delivers value as a maintainable, day-to-day workflow tool.

**Acceptance Scenarios**:

1. **Given** no containers are running, **When** the user runs the provision script with a model name, **Then** the chosen model's container starts and the server becomes available.
2. **Given** containers are running, **When** the user runs the clean script, **Then** all LLM containers and their associated volumes are stopped and removed.
3. **Given** a newer model version is available, **When** the user runs the update script, **Then** the local model image is refreshed without requiring manual Docker commands.
4. **Given** the setup is running, **When** the user runs the status script, **Then** a human-readable summary of running containers, loaded models, and resource usage is displayed.
5. **Given** the user wants to switch models, **When** they run the provision script with a different model name, **Then** the previous model container is replaced by the new one.

---

### User Story 4 - Choose Between Supported Models (Priority: P4)

As a developer, I want to select from multiple supported open source models (DeepSeek-V3, GLM-4, MiniMax-M1) so that I can choose the best model for different coding tasks.

**Why this priority**: Multi-model support enables flexibility but is not required for initial value delivery. A single working model satisfies P1.

**Independent Test**: Can be fully tested by provisioning each supported model in turn and verifying each serves correct responses. Delivers value as a flexible, task-optimized coding environment.

**Acceptance Scenarios**:

1. **Given** a list of supported models, **When** the user specifies any supported model name in the provision script, **Then** that model is started successfully.
2. **Given** an unsupported model name is provided, **When** the user runs the provision script, **Then** an informative error is shown listing supported models.

---

### Edge Cases

- What happens when the host machine has insufficient RAM to load the selected model?
- How does the system handle a Docker image pull failure due to network issues?
- What happens if the requested local port is already in use?
- How does the setup behave when the GPU driver is outdated or incompatible?
- What happens when the user runs the provision script while a container is already running?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The setup MUST support running the following open source models locally: DeepSeek-V3, GLM-4 (open-weight GLM series), and MiniMax-M1 (MiniMax series).
- **FR-002**: Each model MUST run inside a Docker container, isolated from the host system.
- **FR-003**: The setup MUST support GPU-accelerated inference when a compatible GPU is present on the host.
- **FR-004**: The setup MUST provide a CPU-only fallback mode for machines without a compatible GPU.
- **FR-005**: The inference server MUST expose an OpenAI-compatible chat completions API so that AI coding agents (OpenCode, Continue, Aider, etc.) can connect without custom integration work.
- **FR-006**: A provision script MUST start the selected model's container with a single command, accepting the model name and hardware mode (GPU or CPU) as arguments.
- **FR-007**: A clean script MUST stop and remove all LLM containers and their associated resources.
- **FR-008**: An update script MUST pull the latest version of a specified model and restart its container.
- **FR-009**: A status script MUST display the current state of all LLM containers, loaded model names, and basic resource usage.
- **FR-010**: The setup MUST be reproducible — running the provision script on a fresh machine with Docker installed produces a working environment.
- **FR-011**: The inference server MUST respond to a model listing request, returning the name(s) of currently loaded models.
- **FR-012**: All scripts MUST validate inputs and provide descriptive error messages for invalid model names, missing dependencies, or port conflicts.

### Key Entities

- **Model**: A supported open source LLM identified by name and version that can be loaded into a container for inference.
- **Inference Server**: The running container that hosts a model and exposes the chat completion API on a local port.
- **Hardware Profile**: A configuration mode (GPU or CPU) that determines how the container allocates compute resources.
- **Provision Configuration**: The combination of model name, hardware profile, and port assignment that defines a running setup instance.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can go from a fresh machine (with Docker installed) to a working local LLM server in under 10 minutes using only the provided scripts.
- **SC-002**: An AI coding agent (e.g., OpenCode) can connect to the local server and receive a valid code completion response without writing any custom code.
- **SC-003**: All three supported models can be provisioned and switched between using only the provided shell scripts, with no manual Docker commands required.
- **SC-004**: The clean script returns the system to a clean state (no running containers, no orphaned volumes) in under 60 seconds.
- **SC-005**: All scripts provide meaningful error output for 100% of invalid inputs (bad model name, missing Docker, port in use).
- **SC-006**: The setup works on both GPU and CPU modes on a standard developer workstation or laptop.

## Assumptions

- The target user is a developer comfortable with running shell scripts and has Docker (with Compose) installed.
- Host machines are running Linux or macOS; Windows support via WSL2 is a stretch goal and out of scope for v1.
- GPU support targets NVIDIA GPUs via the NVIDIA Container Toolkit; AMD GPU support is out of scope for v1.
- Model weights are downloaded at provision time from public model repositories (e.g., Hugging Face); no pre-bundled weights are shipped with this setup.
- The inference server runs on localhost only by default; exposing it to a local network is out of scope for v1.
- A single model runs at a time per setup instance; running multiple models simultaneously is out of scope for v1.
- The OpenAI-compatible API format is the standard integration protocol; no other wire formats are required.
- Internet access is required at provision time to pull Docker images and model weights; fully offline provisioning is out of scope for v1.
