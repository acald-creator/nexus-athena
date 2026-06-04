# Nexus Athena Proposed Architecture

This document reviews the current `nexus-athena` image and proposes its role in the revised Underground Nexus architecture.

`nexus-athena` should remain the controlled red-team and security testing environment. It should not become part of the SOC control plane, and it should not share broad Docker host access unless a specific lab requires it.

## 1. Current Image

```mermaid
graph TD
    A[kalilinux/kali-bleeding-edge] --> B[Build Tools]
    A --> C[Nmap and Wireshark]
    A --> D[Metasploit Framework]
    A --> E[radare2 Built From Source]
    A --> F[Attack and Lab Automation]
```

Current characteristics:

- Provides separate `amd64` and `arm64` Dockerfiles.
- Uses `kalilinux/kali-bleeding-edge` as the base image.
- Installs offensive and analysis tools such as Nmap, Wireshark, Metasploit Framework, and radare2.
- Builds radare2 from the upstream repository at build time.
- Keeps Terraform out of the default image and prefers Workbench for infrastructure tooling.
- Declares shared volumes for `/var/run`, `/var/lib/docker/volumes`, and `/nexus-bucket`.

## 2. Target Role

```mermaid
graph TD
    A[Athena Red-Team Pod / Container] --> B[Approved Lab Targets]
    A --> C[Packet and Event Generation]
    C --> D[Suricata Sensor]
    C --> E[Wazuh Agents]
    D --> F[SOC Event Pipeline]
    E --> F
    F --> G[Wazuh Dashboard]
```

Target characteristics:

- Runs only in isolated lab networks.
- Generates controlled attack and test traffic for SOC validation.
- Produces repeatable scenarios for Security+ and AI-assisted detection labs.
- Uses explicit network policies to limit what Athena can reach.
- Keeps offensive tooling separate from analyst workbench and SOC services.

## 3. Architecture Recommendations

- Keep Kali as the base for Athena. Chainguard images are a better fit for production services, not for a Kali-based offensive tooling environment.
- Split `amd64` and `arm64` differences into one multi-platform build definition if possible.
- Pin package versions where practical, especially for tools used in repeatable labs.
- Avoid building radare2 directly from a moving branch unless the lab intentionally needs latest upstream behavior.
- Avoid mounting the Docker socket or host Docker paths by default.
- Document which capabilities are required for Wireshark, packet capture, and Metasploit use cases.
- Run Athena with namespace and network isolation by default.

## 4. Open Design Decisions

| Decision | Recommended default | Rationale |
| --- | --- | --- |
| Access method | Do not expose SSH by default; use Docker exec, Kubernetes exec, or a controlled terminal | Reduces exposed services in the red-team container. |
| Packet capture permissions | Grant only for labs that require capture | Capabilities such as `NET_ADMIN` and `NET_RAW` should be explicit. |
| Terraform location | Move Terraform to Workbench by default | Athena should focus on red-team and lab traffic generation. |
| Default tool set | Keep a small Kali baseline with optional lab-specific layers | Reduces image size and makes labs more repeatable. |
| Traffic labeling | Add scenario labels through environment variables and output paths | SOC dashboards should distinguish training traffic from real alerts. |
| Host Docker access | Disabled by default | Docker socket access is too broad for normal Athena use. |

Recommended profiles:

| Profile | Purpose | Privilege level |
| --- | --- | --- |
| `athena-standard` | Basic red-team commands against approved lab targets | Unprivileged or minimal capabilities |
| `athena-packet-lab` | Wireshark, packet capture, network analysis | Explicit network capabilities |
| `athena-exploit-lab` | Metasploit or attack simulation labs | Isolated network, explicit approval |

## 5. First Implementation Milestone

The first revision should make Athena safer and more repeatable without removing its red-team purpose.

Milestone scope:

- Add a documented runtime profile for Docker and Kubernetes.
- Remove default host Docker mounts from normal operation.
- Add labels and environment variables for lab scenario identity.
- Pin or intentionally track versions for radare2 and any optional tooling layers.
- Document required Linux capabilities for packet capture labs.
