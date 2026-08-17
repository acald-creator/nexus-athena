# Claude Instructions

Use `architecture.md` as the canonical architecture guide for this repository.

## Strengths for This Repo

- Threat modeling Athena runtime profiles and capability escalation paths.
- Reviewing isolation boundaries between red-team container and SOC pipeline.
- Checking whether offensive tooling is scoped to approved lab targets.
- Finding places where Dockerfiles or docs imply unsafe default privileges.
- Reviewing LLM agent safety controls (allowlist integrity, rate limiting, capability gates).
- Validating that autonomous execution paths have human review checkpoints.

## Output Expectations

- Return findings with file references.
- Avoid rewriting implementation unless explicitly asked.
- When reviewing agent-related changes, verify safety controls cover every autonomous action path.
- Flag any profile that grants capabilities without documenting the justification.
