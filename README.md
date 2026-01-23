# k3s Home Lab on libvirt

**Production-grade Kubernetes cluster running on your home lab at zero cloud cost.**

This repository provides Infrastructure as Code (IaC) to deploy a 3-node k3s cluster on libvirt/QEMU. Perfect for learning, development, and demonstrating platform engineering skills without monthly cloud bills.

## Features

- **Zero Cloud Costs** - Runs entirely on your existing hardware
- **Production Patterns** - Multi-node cluster, proper networking, persistent storage
- **Automated Deployment** - Packer for images, Terraform for infrastructure
- **Reusable** - Works on any Linux system with libvirt/QEMU
- **Fast** - From `make cluster-up` to working cluster in ~10 minutes

## Architecture

**Cluster Composition:**
- 1x Control Plane node (`k3s-cp-01`)
- 2x Worker nodes (`k3s-worker-01`, `k3s-worker-02`)

**Node Specifications:**
- 6 vCPUs per node
- 10GB RAM per node
- 80GB disk per node
- Ubuntu 24.04 LTS

**Network:**
- Bridge networking (VMs get IPs on your LAN)
- Automatic DHCP assignment
- k3s uses flannel CNI

## Prerequisites

### Deployment Options

**Option A: Local Deployment (All on NUC)**
- Run Packer, Terraform, and kubectl directly on the NUC
- Simplest setup, all tools on one machine
- **Required on NUC:** libvirt/QEMU, Packer, Terraform, Make

**Option B: Remote Management (Recommended)**
- NUC runs only libvirtd + Packer (hypervisor)
- Laptop manages cluster via SSH with containerized tools
- Cleaner separation, minimal NUC installation
- **Required on NUC:** libvirt/QEMU, Packer
- **Required on Laptop:** Docker/Podman, SSH access
- See [NUC Hypervisor Setup Guide](docs/nuc-hypervisor-setup.md)

### System Requirements

- **CPU:** 18+ cores (or accept slower performance)
- **RAM:** 32GB minimum (30GB for VMs + 2GB host overhead)
- **Disk:** 250GB free space recommended
- **OS:** Linux (tested on Ubuntu 22.04+)

### libvirt Setup

Ensure libvirt is running and you have a bridge network configured:

```bash
# Start libvirtd
sudo systemctl start libvirtd
sudo systemctl enable libvirtd

# Verify networks
sudo virsh net-list --all

# You should see a bridge network (e.g., host-bridge or default)
# If not, create one or use NAT network
```

### Install Tools

#### Option A: Local Deployment (All on NUC)

**Ubuntu/Debian:**
```bash
# Packer
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install packer

# Terraform
sudo apt-get install terraform

# libvirt/QEMU (if not already installed)
sudo apt-get install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils

# Add user to required groups
sudo usermod -aG kvm,libvirt $USER

# Log out and back in for group changes to take effect
```

#### Option B: Remote Management

**On NUC:**
```bash
# Packer (for image building)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install packer

# libvirt/QEMU (if not already installed)
sudo apt-get install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils

# Add user to required groups
sudo usermod -aG kvm,libvirt $USER

# Log out and back in for group changes to take effect

# Configure for remote access
sudo ./scripts/configure-libvirt-remote.sh
```

**On Laptop:**
```bash
# Docker (for containerized Terraform/kubectl)
# Install Docker Desktop or Docker Engine

# Verify SSH access to NUC
ssh user@nuc-hostname 'virsh list --all'
```

See [NUC Hypervisor Setup Guide](docs/nuc-hypervisor-setup.md) for detailed remote setup.

## Quick Start

### Option A: Local Deployment (All on NUC)

### 1. Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/k3s-homelab.git
cd k3s-homelab
```

### 2. Configure Variables

```bash
# Copy example configuration
cp terraform-libvirt/terraform.tfvars.example terraform-libvirt/terraform.tfvars

# Edit with your settings
vim terraform-libvirt/terraform.tfvars
```

**Minimum required configuration:**

```hcl
# terraform-libvirt/terraform.tfvars
ssh_public_key_path = "~/.ssh/id_rsa.pub"  # Your SSH public key
libvirt_network     = "host-bridge"        # Your libvirt network name
```

### 3. Build Base Image

```bash
# Build Ubuntu 24.04 image with cloud-init
make image
```

This creates `/home/YOUR_USER/libvirt_images/k3s-node-ubuntu-24.04.qcow2`

**Using a local ISO (faster if you already have it):**

```bash
# Download ISO first
wget https://releases.ubuntu.com/24.04/ubuntu-24.04.1-live-server-amd64.iso

# Build with local ISO
cd packer/k3s-node
packer build \
  -var "ubuntu_iso_url=file:///path/to/ubuntu-24.04.1-live-server-amd64.iso" \
  -var "ubuntu_iso_checksum=none" \
  .
```

### 4. Deploy Cluster

```bash
# Create 3-node k3s cluster
make cluster-up
```

This will:
- Create 3 VMs using Packer image
- Configure networking and storage
- Install k3s on all nodes
- Join workers to control plane
- Output node IP addresses

---

### Option B: Remote Management (Hybrid Deployment)

With this approach, the NUC only runs VMs while your laptop manages everything.

### 1. Setup NUC (One-Time)

See [NUC Hypervisor Setup Guide](docs/nuc-hypervisor-setup.md) for complete instructions.

**Quick version:**
```bash
# On NUC
git clone https://github.com/YOUR_USERNAME/k3s-homelab.git
cd k3s-homelab

# Configure libvirt for remote access
sudo ./scripts/configure-libvirt-remote.sh

# Download Ubuntu ISO
wget https://releases.ubuntu.com/24.04/ubuntu-24.04.1-live-server-amd64.iso
```

### 2. Build Base Image (On NUC)

Packer requires direct QEMU access, so run this on the NUC:

```bash
# On NUC
cd k3s-homelab/packer/k3s-node
packer build \
  -var "ubuntu_iso_url=file://$HOME/ubuntu-24.04.1-live-server-amd64.iso" \
  -var "ubuntu_iso_checksum=none" \
  .
```

### 3. Deploy Cluster (From Laptop)

**Test remote connection:**
```bash
# On laptop
virsh -c qemu+ssh://user@nuc-hostname/system list --all
```

**Deploy with containerized Terraform:**
```bash
# On laptop
cd k3s-homelab

# Update terraform.tfvars with remote libvirt URI
vim terraform-libvirt/terraform.tfvars

# Deploy cluster
docker run --rm \
  -v $(PWD)/terraform-libvirt:/workspace \
  -v ~/.ssh:/root/.ssh:ro \
  -w /workspace \
  -e LIBVIRT_DEFAULT_URI=qemu+ssh://user@nuc-hostname/system \
  hashicorp/terraform:latest \
  apply -auto-approve
```

### 4. Access Cluster (From Laptop)

```bash
# Get kubeconfig from control plane
ssh user@nuc-hostname 'sudo cat /etc/rancher/k3s/k3s.yaml' > ~/.kube/k3s-homelab.yaml

# Update server IP in kubeconfig
sed -i 's/127.0.0.1/<control-plane-ip>/' ~/.kube/k3s-homelab.yaml

# Use kubectl from container
docker run --rm \
  -v ~/.kube:/root/.kube:ro \
  -e KUBECONFIG=/root/.kube/k3s-homelab.yaml \
  bitnami/kubectl:latest \
  get nodes
```

---

## Common to Both Options

---

## Common to Both Options

### 5. Access Your Cluster

**From NUC (Local):**
```bash
# SSH to control plane
ssh ubuntu@<k3s-cp-01-ip>

# Get kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml

# Copy to your local machine and update server IP
# Then use kubectl locally
export KUBECONFIG=~/k3s-homelab-kubeconfig.yaml
kubectl get nodes
```

**From Laptop (Remote):**
```bash
# Get kubeconfig
ssh user@nuc-hostname 'sudo cat /etc/rancher/k3s/k3s.yaml' > ~/.kube/k3s-homelab.yaml

# Update server IP in kubeconfig
sed -i 's/127.0.0.1/<control-plane-ip>/' ~/.kube/k3s-homelab.yaml

# Use kubectl (containerized or local)
kubectl --kubeconfig ~/.kube/k3s-homelab.yaml get nodes
```

### 6. Destroy Cluster

```bash
# Remove all VMs (keeps base image)
make cluster-down

# Remove everything including base image
make clean
```

## Configuration Options

### Terraform Variables

Edit `terraform-libvirt/terraform.tfvars`:

```hcl
# Required
ssh_public_key_path = "~/.ssh/id_rsa.pub"

# Optional - Network
libvirt_network = "host-bridge"           # Your bridge network name
libvirt_pool    = "libvirt_images"        # Storage pool name

# Optional - Node Sizing
control_plane_vcpu   = 6                  # vCPUs for control plane
control_plane_memory = 10240              # Memory in MB
worker_vcpu          = 6                  # vCPUs per worker
worker_memory        = 10240              # Memory in MB
disk_size            = 85899345920        # 80GB in bytes

# Optional - k3s Version
k3s_version = "v1.31.1+k3s1"              # Specific version, or omit for latest
```

### Packer Variables

Edit `packer/k3s-node/variables.pkr.hcl` for image customization:

```hcl
ubuntu_version = "24.04"
disk_size      = "80G"
memory         = "2048"
cpus           = "2"
```

## Network Architecture

**Default: Bridge Networking**

VMs connect to your existing bridge network and receive IPs via DHCP from your router.

**Advantages:**
- VMs accessible from your LAN
- Easy external access (Cloudflare Tunnel, etc.)
- Simpler than NAT + port forwarding

**Alternative: NAT Networking**

If you don't have a bridge network, use libvirt's default NAT network:

```hcl
# terraform-libvirt/terraform.tfvars
libvirt_network = "default"
```

VMs will be on private 192.168.122.0/24 network. You'll need port forwarding for external access.

## Storage

**Local Storage:**
k3s includes local-path-provisioner for dynamic PV provisioning.

**NFS (Optional):**
Configure NFS server and add storage class for shared storage across nodes.

## Troubleshooting

### Image Build Fails

**Problem:** Packer can't connect to libvirt

**Solution:**
```bash
# Ensure libvirtd is running
sudo systemctl status libvirtd

# Check your user is in libvirt group
sudo usermod -aG libvirt $USER
newgrp libvirt
```

### Terraform Apply Fails

**Problem:** `Error: storage pool not found`

**Solution:**
```bash
# List available pools
sudo virsh pool-list --all

# Update terraform.tfvars with correct pool name
libvirt_pool = "your-pool-name"
```

**Problem:** Network not found

**Solution:**
```bash
# List networks
sudo virsh net-list --all

# Start network if inactive
sudo virsh net-start host-bridge

# Update terraform.tfvars
libvirt_network = "host-bridge"
```

### Can't SSH to VMs

**Problem:** Connection refused or timeout

**Solution:**
```bash
# Find VM IPs
sudo virsh net-dhcp-leases host-bridge

# Ensure your SSH key is correct
cat terraform-libvirt/terraform.tfvars | grep ssh_public_key_path

# Verify cloud-init completed
sudo virsh console k3s-cp-01
# Login as ubuntu (no password needed if console access works)
# Check: sudo cloud-init status
```

### k3s Not Running

**Problem:** k3s service failed to start

**Solution:**
```bash
# SSH to node
ssh ubuntu@<node-ip>

# Check k3s status
sudo systemctl status k3s
# or
sudo systemctl status k3s-agent

# View logs
sudo journalctl -u k3s -f
```

## Make Targets

```bash
make image         # Build base image with Packer
make cluster-up    # Deploy cluster with Terraform
make cluster-down  # Destroy cluster (keeps image)
make clean         # Remove cluster and base image
make validate      # Validate Packer and Terraform configs
```

## What's Next?

Once your cluster is running:

1. **Install Big Bang** - DoD DevSecOps platform
   ```bash
   # Deploy Flux GitOps
   flux bootstrap github --owner=YOUR_USER --repository=fleet-infra
   ```

2. **Deploy Applications** - Use ArgoCD or Flux
   ```bash
   kubectl apply -f applications/
   ```

3. **Add Monitoring** - Prometheus + Grafana
   ```bash
   helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack
   ```

4. **External Access** - Cloudflare Tunnel
   ```bash
   # Install cloudflared in cluster
   kubectl apply -f cloudflare-tunnel/
   ```

## Cost Comparison

**Home Lab (This Setup):**
- Hardware: $0 (existing system)
- Electricity: ~$10-20/month
- **Total: $0-20/month**

**AWS EKS Equivalent:**
- EKS Control Plane: $73/month
- 3x t3a.medium nodes: ~$45/month
- Network/Storage: ~$20/month
- **Total: ~$138/month = $1,656/year**

**Savings: $1,400-1,600 per year**

## Contributing

This is a reference implementation for home lab k3s deployments. Improvements welcome:

- Additional cloud-init configurations
- Alternative network setups
- Storage class examples
- Platform service integrations

## License

MIT License - See [LICENSE](LICENSE) file

## Links

- [k3s Documentation](https://docs.k3s.io/)
- [Terraform Libvirt Provider](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs)
- [Packer QEMU Builder](https://developer.hashicorp.com/packer/plugins/builders/qemu)
- [Big Bang](https://repo1.dso.mil/big-bang/bigbang)

---

**Author:** Xavier Lopez  
**Blog:** [xavierlopez.me](https://xavierlopez.me)  
**GitHub:** [@eckslopez](https://github.com/eckslopez)
