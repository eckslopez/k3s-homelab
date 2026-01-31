# CLAUDE.md - Context for AI Assistants

## Project Overview

**Repository:** kubernetes-platform-infrastructure (kpi)

This repository provides Infrastructure as Code to deploy a production-grade 3-node k3s cluster on KVM/libvirt virtualization. The cluster is designed to run platform services (Big Bang DevSecOps baseline) and applications as part of the ZaveStudios platform engineering portfolio.

**Key principle:** Cloud-ready, not cloud-dependent. The architecture uses standard Kubernetes primitives and is designed for portability between virtualization platforms and cloud providers.

## Current State (January 2025)

**✅ Completed:**
- 3-node k3s cluster (1 control plane, 2 workers) running on libvirt
- Fully automated deployment via Terraform + cloud-init
- Deployment time: ~5 minutes from `terraform apply` to operational cluster
- Static IP networking (192.168.122.10-12)
- Pinned k3s version: v1.34.3+k3s1
- Robust network validation before k3s installation
- Clean base images (no state leakage between deployments)

**🔄 Current Phase:** Phase I - Foundation & Bootstrap (~15% complete)

**📝 Blog Post:** "Building a Production-Grade k3s Cluster on Spare Capacity" drafted, ready to publish

## Architecture

**Node Configuration:**
- Control plane: k3s-cp-01 @ 192.168.122.10 (6 vCPU, 10GB RAM, 80GB disk)
- Worker 1: k3s-worker-01 @ 192.168.122.11 (6 vCPU, 10GB RAM, 80GB disk)
- Worker 2: k3s-worker-02 @ 192.168.122.12 (6 vCPU, 10GB RAM, 80GB disk)
- OS: Ubuntu 24.04 LTS
- Runtime: containerd

**Network:**
- libvirt default network (192.168.122.0/24)
- Static IPs via cloud-init network_config
- DNS: 8.8.8.8, 1.1.1.1

**Deployment Stack:**
- Packer: Base Ubuntu 24.04 image with k3s prerequisites
- Terraform: VM provisioning via dmacvicar/libvirt provider
- Cloud-init: Node configuration and k3s installation

## Next Actions

### Immediate: Issue #2 - Bootstrap Flux GitOps

**Goal:** Install Flux v2 controllers to enable GitOps-based platform management

**Decisions needed:**
1. Where to store Flux configuration manifests (new repo: `zavestudios-gitops` or within kpi repo?)
2. Bootstrap target (GitHub recommended for now, self-hosted GitLab later)
3. Installation method (`flux bootstrap github` recommended)

**Steps:**
1. Install Flux CLI on management machine
2. Create Git repository for Flux configs
3. Run `flux bootstrap github` pointing to new repo
4. Verify Flux controllers are running in cluster
5. Create initial GitRepository and Kustomization resources

**Success criteria:**
- Flux controllers operational in cluster
- Flux syncing from Git repository
- Ready to deploy Big Bang platform services

### Following: Issue #3 - Deploy Big Bang Platform

**Goal:** Deploy DoD DevSecOps baseline platform services via Flux

**Core services to deploy:**
- GitLab (self-hosted CI/CD)
- ArgoCD (application GitOps)
- Istio (service mesh)
- Prometheus/Grafana (observability)

**Configuration considerations:**
- Single-node deployment (not HA)
- Resource-constrained environment
- Custom Big Bang values for sandbox environment

**Big Bang Configuration:**
- Using Big Bang chart-of-charts pattern
- Pointing to upstream public Helm repositories (not repo1.dso.mil)
- No Iron Bank registry dependency
- Maintains integration benefits of Big Bang without authentication requirements

## Key Technical Decisions

### Static IPs vs DHCP
**Decision:** Use cloud-init network_config for static IPs
**Rationale:** Eliminates DHCP lease instability, ensures predictable networking
**Implementation:** Each VM gets network_config via cloud-init ISO

### Pinned k3s Version
**Decision:** Use explicit version (v1.34.3+k3s1) not "stable" channel
**Rationale:** Reproducible deployments, controlled upgrades, easier troubleshooting
**Trade-off:** Manual version updates vs automatic latest

### Network Validation
**Decision:** Validate network and DNS before k3s installation
**Rationale:** Prevents timing-related failures in certificate generation and API server binding
**Cost:** 10-15 seconds added to deployment time

### Clean Base Images
**Decision:** Remove all machine-specific state from Packer images
**Rationale:** Prevents MAC address conflicts, cloud-init state issues, network misconfigurations
**Implementation:** Cleanup script removes machine-id, cloud-init state, netplan configs

## File Structure

```
kubernetes-platform-infrastructure/
├── terraform-libvirt/
│   ├── main.tf                    # VM definitions, cloud-init resources
│   ├── variables.tf               # Input variables
│   ├── outputs.tf                 # IP addresses, connection info
│   ├── terraform.tfvars.example   # Example configuration
│   └── cloud-init/
│       ├── k3s-cp.yml.tpl        # Control plane cloud-init
│       ├── k3s-worker.yml.tpl    # Worker cloud-init
│       └── network-config.yml.tpl # Network configuration
├── packer/
│   └── k3s-node/
│       ├── k3s-node.pkr.hcl      # Packer template
│       ├── variables.pkr.hcl      # Packer variables
│       └── scripts/
│           └── setup.sh           # Provisioning + cleanup script
├── scripts/
│   ├── cleanup-terraform-state.sh    # Remove resources from state
│   └── cleanup-libvirt-resources.sh  # Destroy VMs/volumes
└── docs/
    └── adrs/
        └── 004-hybrid-home-lab-aws-architecture.md  # Architecture rationale
```

## Development Workflow

**Standard deployment:**
```bash
# From laptop (Terraform runs in Docker, connects to zave-lab via SSH)
docker compose run --rm terraform apply

# Wait ~5 minutes for cloud-init to complete

# Access control plane
ssh -J xlopez@192.168.1.11 ubuntu@192.168.122.10

# Verify cluster
sudo k3s kubectl get nodes -o wide
```

**Rebuild cluster:**
```bash
docker compose run --rm terraform destroy
docker compose run --rm terraform apply
```

**Access from laptop:**
```bash
# Get kubeconfig from control plane
ssh -J xlopez@192.168.1.11 ubuntu@192.168.122.10 'sudo cat /etc/rancher/k3s/k3s.yaml' > ~/.kube/kpi.yaml

# Update server IP
sed -i 's/127.0.0.1/192.168.122.10/' ~/.kube/kpi.yaml

# Use kubectl
export KUBECONFIG=~/.kube/kpi.yaml
kubectl get nodes
```

## Content Voice & Documentation Standards

When writing documentation or blog posts about this project:

- **Show, don't argue:** Describe what was built, not why it's better than alternatives
- **Evidence-based:** Every claim must be backed by actual implementation
- **Honest about state:** Clear about what's done vs. what's planned
- **No overconfidence:** Let the quality of work speak for itself
- **Technical but accessible:** Write for platform engineers and hiring managers

## Related Projects

- **zavestudios** - Overall platform architecture and documentation
- **bigbang** (planned) - Big Bang platform configuration
- **terraform-modules** (planned) - Reusable Terraform modules
- **xavierlopez.me** - Blog with technical writing about platform decisions

## Resources

- [k3s Documentation](https://docs.k3s.io/)
- [Terraform Libvirt Provider](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs)
- [Flux Documentation](https://fluxcd.io/flux/)
- [Big Bang](https://repo1.dso.mil/big-bang/bigbang)
- ADR-004: Hybrid Sandbox + AWS Architecture (../zavestudios/docs/adrs/004-hybrid-home-lab-aws-architecture.md)

---

**Last Updated:** January 28, 2025
**Next Milestone:** Flux GitOps bootstrap (Issue #2)
