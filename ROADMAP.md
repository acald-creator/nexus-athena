# Nexus Athena Roadmap

This roadmap tracks the next implementation steps for the Athena adversary emulation component.

## Near-Term

1. Fix GitHub Actions workflows to publish Athena images to multiple container registries.
2. Split runtime profiles in build and deployment docs so privileged lab modes are explicit and opt-in.
3. Improve reproducibility for multi-architecture builds (`amd64` and `arm64`) with pinned build inputs.

## Mid-Term

1. Introduce multi-stage Docker builds for smaller, easier-to-audit images.
2. Evaluate a scratch-style or minimal-runtime variant where compatible with required tooling.
3. Add automated validation for runtime profile assumptions (network caps, tool availability, and expected isolation).

## Long-Term

1. Stand up an internal container registry on Kubernetes for trusted artifact distribution.
2. Integrate signed images and SBOM workflows into CI release gates.
3. Align Athena release lifecycle with Underground Nexus component maturity gates.
