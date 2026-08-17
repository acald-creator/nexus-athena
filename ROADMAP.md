# Nexus Athena Roadmap

This roadmap tracks implementation steps for the Athena adversary emulation component.

## Completed

- [x] Multi-stage Docker build (athena-core + athena-full targets, multi-platform via buildx)
- [x] Runtime profiles split: standard, packet-lab, exploit-lab, agent, agent-ics
- [x] Compose profiles for all 5 runtime modes with proper capability declarations
- [x] Profile launcher script (`scripts/run-athena-profile.sh`) handling all profiles
- [x] Profile validation script (`scripts/validate-athena-profiles.sh`)
- [x] Kubernetes base manifests + local/prod overlays
- [x] Architecture doc with LLM agent integration (Section 5)
- [x] LLM agent mode: OPAR loop operational in `athena-agents` repo
- [x] Traffic labeling (env vars + HTTP headers for SOC dashboard filtering)

## Near-Term

1. Add Kubernetes agent profile overlays (agent + agent-ics kustomize patches).
2. Improve reproducibility for multi-architecture builds with pinned package versions.
3. Add automated SBOM generation to local build workflow (syft/trivy).
4. Validate compose profiles in a CI-like environment (GitHub Actions when fork constraints allow).

## Mid-Term

1. Evaluate a scratch-style or minimal-runtime variant for the agent profile (no full Kali needed for OPAR).
2. Add target network simulation (compose services that emulate Modbus PLCs, CAN bus interfaces).
3. Integrate ground-truth output with `nexus-webtop-soc` SOC baseline stack for closed-loop evaluation.
4. Add skill persistence from agent Reflect phase back to MinIO `nexus-memory/skills/`.

## Long-Term

1. Stand up an internal container registry on Kubernetes for trusted artifact distribution.
2. Integrate signed images and SBOM workflows into CI release gates.
3. Align Athena release lifecycle with Underground Nexus component maturity gates.
4. Headless agent execution with approval queue integration (nexus-tui or API-driven).
5. Multi-agent coordination (parallel OPAR loops against different targets with shared observation).
