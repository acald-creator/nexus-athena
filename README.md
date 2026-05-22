# Nexus Athena

Nexus Athena is the controlled red-team and adversary emulation environment for Underground Nexus.

Athena should generate repeatable lab traffic, packet captures, and adversarial test cases for approved targets. It should not become part of the SOC control plane, and it should not receive broad host access unless a specific lab profile requires it.

## Current Status

The current image is based on Kali Linux and includes tools such as Nmap, Wireshark, Metasploit Framework, radare2, and Terraform. The architecture direction is to keep Athena as an isolated lab workload while moving privileged capabilities into explicit runtime profiles.

See [architecture.md](architecture.md) for the proposed architecture.

## Role in Underground Nexus

Athena is responsible for:

- Controlled adversary emulation.
- Security+ and purple-team lab traffic generation.
- Packet and event generation for Suricata, Wazuh, and AI triage validation.
- Repeatable attack simulation against approved lab targets.

Athena is not responsible for:

- SOC event storage.
- SOC dashboard hosting.
- Analyst desktop workflows.
- Production control-plane automation.
- Unrestricted Docker host administration.

## Recommended Profiles

| Profile | Purpose | Default privilege |
| --- | --- | --- |
| `athena-standard` | Basic red-team commands against approved lab targets | Unprivileged or minimal capabilities |
| `athena-packet-lab` | Wireshark, packet capture, and network analysis | Explicit `NET_ADMIN` or `NET_RAW` only when needed |
| `athena-exploit-lab` | Metasploit and exploit simulation labs | Isolated network, explicit approval |

Runtime assets:

- Docker Compose profiles: `deploy/compose/athena-profiles.yml`
- Kubernetes base and overlays: `deploy/kubernetes/base`, `deploy/kubernetes/overlays/local`, `deploy/kubernetes/overlays/prod`

## Build Images

The repository currently keeps separate Dockerfiles:

```text
Dockerfile
Dockerfile.arm64
```

Example build:

```sh
VERSION=$(git log -1 --pretty=%h)
BUILD_TIMESTAMP=$(date '+%F_%H:%M:%S')

docker buildx build \
    -t <registry>/nexus-athena:$VERSION \
    -t <registry>/nexus-athena:latest \
    --build-arg VERSION="$VERSION" \
    --build-arg BUILD_TIMESTAMP="$BUILD_TIMESTAMP" \
    .
```

## Runtime Profiles

### Docker Compose

```sh
# Standard profile (default)
./scripts/run-athena-profile.sh standard

# Packet capture lab profile (adds NET_ADMIN and NET_RAW)
./scripts/run-athena-profile.sh packet-lab

# Tear down
./scripts/run-athena-profile.sh down
```

### Kubernetes

```sh
# Preview local overlay
kubectl kustomize deploy/kubernetes/overlays/local

# Apply local overlay
kubectl apply -k deploy/kubernetes/overlays/local

# Optional: scale up packet-lab only when explicitly needed
kubectl -n nexus-athena scale deploy/athena-packet-lab --replicas=1
```

## Supply Chain

This repository includes:

- `cosign.pub`
- `athena0-latest.spdx`

Historical Cosign, Syft, and registry-specific examples should move into dedicated supply-chain documentation if they need to be preserved. The README should stay focused on the repo purpose, build path, runtime profiles, and architecture direction.

## AI Collaboration

AI assistants should use these entrypoints:

- [AGENTS.md](AGENTS.md) for Codex-style coding agents.
- [CLAUDE.md](CLAUDE.md) for architecture critique and threat modeling.
- [GEMINI.md](GEMINI.md) for research and platform comparison.
- [architecture.md](architecture.md) as the source of truth for the proposed Athena role.

## Local-Only and Deprecated Direction

| Item | Status | Direction |
| --- | --- | --- |
| Broad Docker socket or host Docker mounts | Deprecated default | Disable by default; enable only for explicit lab profiles. |
| Exposed SSH | Deprecated default | Prefer `docker exec`, Kubernetes exec, or controlled terminal access. |
| Moving upstream source builds | Review required | Pin versions where repeatability matters. |
| Terraform inside Athena | Optional | Prefer Workbench for infrastructure tooling unless a red-team lab requires Terraform. |

## License

See [LICENSE](LICENSE).
