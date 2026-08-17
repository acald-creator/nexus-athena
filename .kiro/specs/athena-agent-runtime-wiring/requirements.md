# Requirements Document

## Introduction

Wire the `athena-agents` OPAR orchestrator into the `nexus-athena` Docker container so that running `./scripts/run-athena-profile.sh agent` actually starts the autonomous observe/plan/act/reflect loop against a configured target. Currently the agent compose services run `sleep infinity` — this feature replaces that with a proper entrypoint that bootstraps the Python orchestrator with all required configuration, safety controls, and ground-truth emission wired to a mounted volume or stdout.

The scope covers packaging the `athena-agents` Python code into the container image, mounting or baking in configuration files (tool-registry, allowlist, target configs, LLM backend config), configuring the entrypoint/command for agent profiles, and ensuring the safety controls (allowlist SHA-256 verification, rate limiter, capability gates) remain enforced at runtime.

## Glossary

- **OPAR_Loop**: The Observe/Plan/Act/Reflect execution cycle implemented in `orchestrator/agent.py` that drives autonomous offensive testing.
- **Agent_Entrypoint**: The container command that bootstraps and starts the OPAR loop with the correct configuration and environment.
- **Tool_Registry**: The TOML configuration (`config/tool-registry.toml`) mapping tool identifiers to executables, argument schemas, and capability requirements.
- **Allowlist**: The JSON file (`config/allowlist.json`) enumerating approved targets with port ranges, verified by SHA-256 hash at startup.
- **Ground_Truth_Emitter**: The component that writes JSON Lines telemetry records describing each action's outcome for SOC consumption.
- **Capability_Gate**: The runtime check that prevents tools from executing if their required capabilities (e.g., `ICS_WRITE`, `NET_RAW`) are not present in the active profile.
- **Agent_Profile**: A Docker Compose service definition (`athena.agent` or `athena.agent-ics`) with specific capabilities and environment variables for LLM-driven execution.
- **LLM_Backend**: The inference endpoint (Ollama, vLLM, or llama.cpp) used by the orchestrator for planning decisions, configured via `config/llm.toml` and `OLLAMA_HOST` env var.
- **Scenario_Config**: A target configuration file (`config/targets/*.toml`) defining the host, port, protocol, and vulnerability categories for a scenario.
- **Athena_Image**: The `nexus-athena` Docker image built from the repository Dockerfile, serving as the base runtime environment.
- **Config_Volume**: A Docker volume or bind mount providing configuration files to the container at runtime.
- **GT_Volume**: A Docker volume or bind mount where ground-truth JSON Lines output is persisted for external consumption.

## Requirements

### Requirement 1: Agent Entrypoint Bootstrap

**User Story:** As a red-team operator, I want `./scripts/run-athena-profile.sh agent` to start the OPAR loop automatically, so that I do not need to manually exec into the container and launch the orchestrator.

#### Acceptance Criteria

1. WHEN the `athena.agent` compose service starts, THE Agent_Entrypoint SHALL launch the OPAR_Loop using `python3 -m orchestrator` with configuration paths resolved from environment variables.
2. WHEN the `athena.agent-ics` compose service starts, THE Agent_Entrypoint SHALL launch the OPAR_Loop with `ATHENA_CAPABILITIES=ICS_WRITE,CAN_INJECT` set in the process environment.
3. IF the Agent_Entrypoint fails to locate required configuration files, THEN THE Agent_Entrypoint SHALL exit with a non-zero status code and log a descriptive error identifying the missing file.
4. WHEN no `ATHENA_TARGET` environment variable is set, THE Agent_Entrypoint SHALL exit with a non-zero status code and log an error indicating the target must be specified.
5. THE Agent_Entrypoint SHALL set `PYTHONUNBUFFERED=1` so that ground-truth output is flushed immediately.

### Requirement 2: Python Orchestrator Packaging

**User Story:** As a platform engineer, I want the `athena-agents` Python orchestrator available inside the `nexus-athena` image, so that the agent profiles can run without external volume mounts for code.

#### Acceptance Criteria

1. THE Athena_Image SHALL include the `athena-agents` Python package installed via pip in a dedicated stage of the multi-stage Docker build.
2. THE Athena_Image SHALL include all Python dependencies declared in `athena-agents/pyproject.toml` (`pydantic>=2.0`, `httpx>=0.25`, `tomli>=2.0`).
3. THE Athena_Image SHALL place the installed orchestrator module at a path discoverable by `python3 -m orchestrator` without additional `PYTHONPATH` manipulation.
4. WHEN the image is built, THE Athena_Image SHALL pin dependency versions via a lockfile or hash-verified install to ensure reproducible builds.
5. THE Athena_Image SHALL NOT include development dependencies (`pytest`, `hypothesis`, `ruff`) in the final runtime layer.

### Requirement 3: Configuration File Provisioning

**User Story:** As a red-team operator, I want tool-registry, allowlist, LLM backend config, and target configs available to the orchestrator at runtime, so that the OPAR loop can start without manual file setup.

#### Acceptance Criteria

1. THE Agent_Profile compose services SHALL mount a configuration directory containing `tool-registry.toml`, `allowlist.json`, `allowlist.sha256`, `llm.toml`, and the `targets/` subdirectory at the path specified by `ATHENA_CONFIG_DIR` (default: `/opt/athena/config`).
2. WHEN the container starts, THE Agent_Entrypoint SHALL verify that `tool-registry.toml` and `allowlist.json` exist at the configured path before launching the OPAR_Loop.
3. THE Agent_Profile compose services SHALL set `ATHENA_TOOL_REGISTRY` to `${ATHENA_CONFIG_DIR}/tool-registry.toml` and `ATHENA_ALLOWLIST` to `${ATHENA_CONFIG_DIR}/allowlist.json`.
4. WHEN a target config file for the specified `ATHENA_TARGET` does not exist in `${ATHENA_CONFIG_DIR}/targets/`, THE Agent_Entrypoint SHALL exit with a non-zero status code and log an error identifying the missing target file.
5. WHERE an operator provides a custom config directory via bind mount, THE Agent_Profile SHALL use the mounted files without requiring a rebuild of the image.

### Requirement 4: LLM Backend Connectivity

**User Story:** As a red-team operator, I want the orchestrator to connect to my local Ollama instance for LLM-driven planning, so that the OPAR loop can produce intelligent action plans.

#### Acceptance Criteria

1. THE Agent_Profile compose services SHALL pass the `OLLAMA_HOST` environment variable (default: `http://host.docker.internal:11434`) to the OPAR_Loop process.
2. WHEN the `config/llm.toml` specifies `type = "ollama"`, THE OPAR_Loop SHALL use the value of `OLLAMA_HOST` as the inference endpoint URL, overriding the `url` field in `llm.toml`.
3. IF the LLM_Backend is unreachable at startup, THEN THE Agent_Entrypoint SHALL retry connection 3 times with exponential backoff (1s, 2s, 4s) before exiting with a non-zero status code and a descriptive error.
4. THE Agent_Profile compose services SHALL include `host.docker.internal:host-gateway` in `extra_hosts` to enable connectivity from the container to the host LLM endpoint.

### Requirement 5: Safety Controls Enforcement

**User Story:** As a security governance lead, I want all safety controls (allowlist verification, capability gates, rate limiting) to remain enforced when the OPAR loop runs inside the container, so that autonomous execution stays within approved boundaries.

#### Acceptance Criteria

1. WHEN the OPAR_Loop starts a scenario, THE Agent_Entrypoint SHALL invoke allowlist SHA-256 verification using the hash from `${ATHENA_CONFIG_DIR}/allowlist.sha256` before executing any actions.
2. IF allowlist verification fails (missing file, hash mismatch, or malformed JSON), THEN THE Agent_Entrypoint SHALL halt the OPAR_Loop, log the failure reason, and exit with a non-zero status code.
3. WHILE the `athena.agent` profile is active (no ICS capabilities), THE Capability_Gate SHALL reject tools requiring `ICS_WRITE` or `CAN_INJECT` capabilities.
4. WHILE the `athena.agent-ics` profile is active, THE Capability_Gate SHALL permit tools requiring `ICS_WRITE` and `CAN_INJECT` capabilities.
5. THE OPAR_Loop SHALL enforce the configured rate limiter so that action throughput does not exceed the defined token-bucket parameters.
6. IF a boundary violation is detected during execution, THEN THE OPAR_Loop SHALL halt immediately, emit a `needs_review` ground-truth record, and exit with a non-zero status code.

### Requirement 6: Ground-Truth Output

**User Story:** As a SOC analyst, I want ground-truth telemetry from the OPAR loop written to a predictable location, so that I can ingest it into dashboards and the nexus-tui for real-time monitoring.

#### Acceptance Criteria

1. THE Agent_Profile compose services SHALL mount a volume at `/opt/athena/output` for ground-truth JSON Lines files.
2. WHEN `ATHENA_GT_OUTPUT` is set (default: `/opt/athena/output/ground-truth.jsonl`), THE Ground_Truth_Emitter SHALL append records to that file path.
3. WHEN `ATHENA_GT_OUTPUT` is unset, THE Ground_Truth_Emitter SHALL write records to stdout so that `docker logs` captures telemetry.
4. THE Ground_Truth_Emitter SHALL flush each record immediately after writing so that downstream consumers observe records without delay.
5. WHEN the OPAR_Loop completes a scenario, THE Ground_Truth_Emitter SHALL write a final summary record containing the `ScenarioResult` termination reason and total action count.

### Requirement 7: Traffic Labeling

**User Story:** As a SOC analyst, I want all traffic generated by the autonomous agent to carry identifying labels, so that I can filter Athena-generated traffic in Wazuh and Suricata dashboards.

#### Acceptance Criteria

1. THE OPAR_Loop SHALL inject `X-Athena-Scenario` and `X-Athena-Run-ID` HTTP headers into all outbound HTTP requests made by tools.
2. THE OPAR_Loop SHALL set `ATHENA_SCENARIO_ID` and `ATHENA_SCENARIO_LABEL` environment variables for all subprocess tool invocations.
3. WHEN `ATHENA_SCENARIO_LABEL` is provided via the compose environment, THE Agent_Entrypoint SHALL pass that value to the orchestrator's `scenario_label` parameter.
4. THE Traffic_Labeler SHALL include a `User-Agent` header containing `Athena-Agent/<version>` in all HTTP-based tool traffic.

### Requirement 8: Compose Profile Updates

**User Story:** As a platform engineer, I want the compose file updated so that agent profiles start the OPAR loop with correct volumes, environment, and entrypoint, so that `run-athena-profile.sh agent` works end-to-end.

#### Acceptance Criteria

1. THE `athena.agent` compose service SHALL replace `command: ["sleep", "infinity"]` with the Agent_Entrypoint command that launches the OPAR_Loop.
2. THE `athena.agent` compose service SHALL define a bind mount from `./config` (or a named volume) to `/opt/athena/config` for configuration files.
3. THE `athena.agent` compose service SHALL define a named volume `athena_output` mounted at `/opt/athena/output` for ground-truth output.
4. THE `athena.agent-ics` compose service SHALL include the same volume mounts and entrypoint as `athena.agent` with the additional `ATHENA_CAPABILITIES=ICS_WRITE,CAN_INJECT` environment variable.
5. WHEN `ATHENA_TARGET` is not set in the environment, THE compose service SHALL default to an empty value so the Agent_Entrypoint can detect and report the missing target.
6. THE compose file SHALL add a `volumes:` top-level section declaring the `athena_output` named volume.

### Requirement 9: Entrypoint Script

**User Story:** As a platform engineer, I want a dedicated entrypoint script that validates the environment before handing off to the Python orchestrator, so that failures are caught early with clear error messages.

#### Acceptance Criteria

1. THE Agent_Entrypoint script SHALL be located at `scripts/athena-agent-entrypoint.sh` in the repository and copied into the image at `/usr/local/bin/athena-agent-entrypoint.sh`.
2. WHEN invoked, THE Agent_Entrypoint script SHALL verify that `ATHENA_TARGET`, `ATHENA_TOOL_REGISTRY`, and `ATHENA_ALLOWLIST` environment variables are non-empty.
3. WHEN invoked, THE Agent_Entrypoint script SHALL verify that the files referenced by `ATHENA_TOOL_REGISTRY` and `ATHENA_ALLOWLIST` exist on disk.
4. WHEN all validation passes, THE Agent_Entrypoint script SHALL exec `python3 -m orchestrator --target "${ATHENA_TARGET}" --config-dir "${ATHENA_CONFIG_DIR:-/opt/athena/config}"` with the current environment.
5. IF any validation step fails, THEN THE Agent_Entrypoint script SHALL print a structured error message to stderr and exit with code 1.
6. THE Agent_Entrypoint script SHALL support an optional `--dry-run` flag that performs validation without starting the orchestrator, exiting with code 0 on success.

### Requirement 10: Run Script Updates

**User Story:** As a red-team operator, I want `run-athena-profile.sh` to accept an optional target argument and pass it through to the container, so that I can specify the target at launch time.

#### Acceptance Criteria

1. WHEN invoked as `./scripts/run-athena-profile.sh agent <target>`, THE run script SHALL set `ATHENA_TARGET=<target>` in the environment before starting the compose service.
2. WHEN invoked as `./scripts/run-athena-profile.sh agent` without a target argument, THE run script SHALL pass through the existing `ATHENA_TARGET` environment variable (which may be empty).
3. WHEN invoked as `./scripts/run-athena-profile.sh agent-ics <target>`, THE run script SHALL set `ATHENA_TARGET=<target>` and start the agent-ics profile.
4. THE run script SHALL print the configured target and LLM endpoint to stdout before starting the compose service for operator confirmation.

### Requirement 11: Dockerfile Integration

**User Story:** As a platform engineer, I want the nexus-athena Dockerfile extended to include the athena-agents orchestrator in the image, so that agent profiles have the Python runtime and code available without external mounts.

#### Acceptance Criteria

1. THE Dockerfile SHALL add a build stage that installs the `athena-agents` Python package from a local context path (build arg `ATHENA_AGENTS_PATH` defaulting to `./athena-agents`).
2. THE Dockerfile SHALL copy the installed Python orchestrator and dependencies into the final `athena-core` or `athena-full` stage at `/usr/local/lib/python3/dist-packages` (or equivalent site-packages path).
3. THE Dockerfile SHALL copy the Rust binaries (`athena-scanner`, `athena-fuzzer`, `athena-crafter`) from the `athena-agents` build into `/usr/local/bin/` in the final image.
4. THE Dockerfile SHALL copy the entrypoint script to `/usr/local/bin/athena-agent-entrypoint.sh` and set it executable.
5. THE Dockerfile SHALL NOT include the `config/` directory in the image — configuration is provided at runtime via volume mounts.
6. THE Dockerfile SHALL set `ATHENA_BIN_DIR=/usr/local/bin` as an environment variable so the tool registry resolves binary paths correctly.
