# Agent Instructions

Use `architecture.md` as the canonical architecture guide for this repository.

## Repository Role

Controlled red-team and adversary emulation container image. Provides Kali-based
offensive tooling for manual, scripted, and LLM-driven autonomous testing.
Also serves as the execution environment for `athena-agents` OPAR loop.

## Key References

- `architecture.md` — container architecture, profiles, LLM agent integration
- `Dockerfile.*` — multi-architecture offensive tooling images
- `.kiro/steering/athena-offensive-context.md` — Kiro workspace context

## Agent Expectations

- Preserve Athena as a controlled red-team and adversary emulation environment.
- Keep offensive tooling isolated from SOC control-plane and analyst desktop responsibilities.
- Avoid adding broad host Docker access to default examples.
- Document runtime privileges as explicit profiles (standard, packet-lab, exploit-lab, agent, agent-ics).
- When modifying Dockerfiles, ensure LLM agent mode requirements are preserved (network access to inference endpoint, tool-registry access).
- Keep changes aligned with the Underground Nexus architecture in `core-nexus`.
- Check `~/.kiro/skills/` for applicable skills (especially `red-team-athena-workflow.md` and `ics-ot-protocol-analysis.md`).

## Cross-Repo Context

| Repository | Relationship |
|------------|-------------|
| `core-nexus` | Architecture hub — this repo must stay aligned |
| `athena-agents` | OPAR loop implementation that runs inside/alongside this container |
| `nexus-webtop-soc` | SOC baseline stack that receives Athena's labeled traffic |

## Guardrails

- Never bypass safe-range validation for ICS/OT targets.
- No default production credentials in Dockerfiles or scripts.
- No broad Docker socket access in default examples.
- Traffic from autonomous agents must be labeled (HTTP headers + env vars).
- Capability gates are non-negotiable — tools declare what they need, profiles grant it.
