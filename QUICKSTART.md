# Quick Start Guide

**Goal:** Get a 3-node k3s cluster running in ~20 minutes.

## Prerequisites Done?

- [ ] libvirtd running
- [ ] Bridge network configured
- [ ] Packer, Terraform installed
- [ ] 32GB+ RAM, 18+ CPU cores

**Not sure?** Run: `./preflight-check.sh`

## Three Commands

```bash
# 1. Configure (one time)
cp terraform-libvirt/terraform.tfvars.example terraform-libvirt/terraform.tfvars
vim terraform-libvirt/terraform.tfvars  # Set your ssh_public_key_path

# 2. Build image (~8 minutes)
make image

# OR use local ISO if you have it:
# wget https://releases.ubuntu.com/24.04/ubuntu-24.04.1-live-server-amd64.iso
# cd packer/k3s-node && packer build -var "ubuntu_iso_url=file:///path/to/ubuntu-24.04.1-live-server-amd64.iso" -var "ubuntu_iso_checksum=none" .

# 3. Deploy cluster (~10 minutes)
make cluster-up
```

## Access Your Cluster

```bash
# Get node IPs
cd terraform-libvirt && terraform output

# SSH to control plane
ssh ubuntu@<control-plane-ip>

# Get kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml > ~/k3s.yaml

# Copy to local machine and edit server IP
scp ubuntu@<control-plane-ip>:~/k3s.yaml ~/.kube/k3s-homelab.yaml
# Edit ~/.kube/k3s-homelab.yaml - change 127.0.0.1 to <control-plane-ip>

# Use kubectl
export KUBECONFIG=~/.kube/k3s-homelab.yaml
kubectl get nodes
```

## Destroy When Done

```bash
make cluster-down  # Removes VMs, keeps image
make clean         # Removes everything
```

## Problems?

See [README.md](README.md) Troubleshooting section.

## What's Running?

- 1x k3s-cp-01 (control plane)
- 2x k3s-worker-01, k3s-worker-02 (workers)
- 18 vCPU total, 30GB RAM total
- Flannel CNI, local-path storage
- No Traefik (so you can install Istio/Big Bang)

## Next Steps

- [Install Big Bang](https://repo1.dso.mil/big-bang/bigbang)
- [Install Flux](https://fluxcd.io/flux/installation/)
- [Deploy apps with ArgoCD](https://argo-cd.readthedocs.io/)
- [Setup Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
