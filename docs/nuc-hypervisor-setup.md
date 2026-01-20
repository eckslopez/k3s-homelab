# NUC Hypervisor Setup Guide

This guide covers setting up your NUC as a dedicated hypervisor for the k3s home lab, managed remotely from your laptop.

## Architecture

```
Laptop (Management Station)
    ├── Terraform (in container) ──SSH──> NUC libvirt
    ├── Packer (SSH to NUC) ──SSH──────> NUC
    └── kubectl (in container) ────────> k3s cluster (in VMs on NUC)

NUC (Hypervisor Only)
    ├── libvirtd + QEMU/KVM
    ├── Bridge network
    ├── Storage pool
    └── 3x VMs running k3s
```

## Prerequisites

- Ubuntu Server 24.04 LTS on NUC
- SSH access to NUC from laptop
- NUC has sufficient resources (32GB+ RAM, 18+ CPU cores recommended)

## Initial NUC Setup

### 1. Install Required Packages

```bash
# On the NUC
sudo apt update
sudo apt install -y \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    bridge-utils \
    virt-manager \
    openssh-server

# Enable and start services
sudo systemctl enable libvirtd
sudo systemctl start libvirtd
sudo systemctl enable ssh
sudo systemctl start ssh
```

### 2. Configure Bridge Network

If you don't already have a bridge network configured:

```bash
# Create bridge network definition
sudo tee /etc/netplan/01-bridge.yaml > /dev/null <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    enp1s0:  # Replace with your interface name (ip a)
      dhcp4: no
  bridges:
    br0:
      interfaces: [enp1s0]
      dhcp4: yes
      parameters:
        stp: false
        forward-delay: 0
EOF

# Apply configuration
sudo netplan apply

# Verify
ip a show br0
```

**Note:** Applying this will briefly disconnect your SSH session as networking reconfigures.

### 3. Configure libvirt Bridge

```bash
# Create libvirt network definition
cat > /tmp/host-bridge.xml <<EOF
<network>
  <name>host-bridge</name>
  <forward mode="bridge"/>
  <bridge name="br0"/>
</network>
EOF

# Define and start network
sudo virsh net-define /tmp/host-bridge.xml
sudo virsh net-start host-bridge
sudo virsh net-autostart host-bridge

# Verify
sudo virsh net-list --all
```

### 4. Configure Storage Pool

```bash
# Create storage directory
mkdir -p ~/libvirt_images

# Define storage pool
cat > /tmp/libvirt-images-pool.xml <<EOF
<pool type='dir'>
  <name>libvirt_images</name>
  <target>
    <path>$HOME/libvirt_images</path>
    <permissions>
      <mode>0755</mode>
      <owner>$(id -u)</owner>
      <group>$(id -g)</group>
    </permissions>
  </target>
</pool>
EOF

# Define and start pool
sudo virsh pool-define /tmp/libvirt-images-pool.xml
sudo virsh pool-start libvirt_images
sudo virsh pool-autostart libvirt_images

# Verify
sudo virsh pool-list --all
```

## Remote Access Configuration

### Option 1: Automated Configuration (Recommended)

```bash
# On the NUC
cd k3s-homelab
sudo ./scripts/configure-libvirt-remote.sh
```

This script:
- Backs up existing libvirtd.conf
- Configures libvirtd for SSH access
- Adds your user to libvirt group
- Restarts libvirtd

### Option 2: Manual Configuration

1. Edit libvirtd configuration:

```bash
sudo vim /etc/libvirt/libvirtd.conf
```

2. Add/uncomment these lines:

```conf
listen_tls = 0
listen_tcp = 0
unix_sock_group = "libvirt"
unix_sock_ro_perms = "0777"
unix_sock_rw_perms = "0770"
access_drivers = [ "polkit" ]
keepalive_interval = 5
keepalive_count = 5
```

3. Add your user to libvirt group:

```bash
sudo usermod -aG libvirt $USER
# Log out and back in for group changes to take effect
```

4. Restart libvirtd:

```bash
sudo systemctl restart libvirtd
```

### Option 3: Use Configuration Template

```bash
# Backup existing config
sudo cp /etc/libvirt/libvirtd.conf /etc/libvirt/libvirtd.conf.backup

# Copy template
sudo cp config-templates/libvirtd.conf.example /etc/libvirt/libvirtd.conf

# Restart
sudo systemctl restart libvirtd
```

## SSH Key Setup

### Generate SSH Key (if needed)

On your laptop:

```bash
# Generate key if you don't have one
ssh-keygen -t ed25519 -C "your-email@example.com"

# Copy to NUC
ssh-copy-id xlopez@<nuc-ip>
```

### Test SSH Access

```bash
# Test basic SSH
ssh xlopez@<nuc-ip> 'hostname'

# Test SSH with command
ssh xlopez@<nuc-ip> 'virsh list --all'
```

## Verify Remote libvirt Access

From your laptop:

```bash
# Test remote libvirt connection
virsh -c qemu+ssh://xlopez@<nuc-ip>/system list --all

# Should return:
# Id   Name   State
# ----------------------
# (empty list is fine - no VMs yet)

# Test network list
virsh -c qemu+ssh://xlopez@<nuc-ip>/system net-list --all

# Should show host-bridge and other networks

# Test storage pool
virsh -c qemu+ssh://xlopez@<nuc-ip>/system pool-list --all

# Should show libvirt_images pool
```

## Packer Installation (NUC Only)

Packer needs direct QEMU access, so it must run on the NUC:

```bash
# On the NUC
# Add HashiCorp GPG key
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -

# Add repository
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

# Install Packer
sudo apt update
sudo apt install packer

# Verify
packer version
```

## Cleanup (Optional)

For a minimal hypervisor-only NUC, remove unnecessary packages:

```bash
# Remove development tools (if moving all dev to laptop)
rm -rf ~/Dev ~/.kube ~/.terraform.d ~/.vagrant.d
rm -rf ~/.rbenv ~/.bundle ~/.vscode ~/.vim ~/.docker

# Remove desktop/GUI packages (if running headless)
rm -rf ~/Desktop ~/Downloads ~/Documents ~/Pictures ~/Videos
rm -rf ~/.mozilla ~/.thunderbird

# Remove old logs and caches
sudo rm -f wget-log*
rm -rf ~/.cache/*
```

## Troubleshooting

### libvirtd Won't Start

```bash
# Check status
sudo systemctl status libvirtd

# Check logs
sudo journalctl -u libvirtd -n 50

# Validate configuration
sudo libvirtd --validate
```

### SSH Connection Refused

```bash
# Verify SSH is running on NUC
sudo systemctl status ssh

# Check firewall (if enabled)
sudo ufw status
sudo ufw allow ssh
```

### Permission Denied on virsh Commands

```bash
# Verify group membership
groups

# Should include 'libvirt'
# If not, re-add and re-login:
sudo usermod -aG libvirt $USER
# Then log out and back in
```

### Remote Connection Times Out

```bash
# Check keepalive settings in libvirtd.conf
grep keepalive /etc/libvirt/libvirtd.conf

# Should show:
# keepalive_interval = 5
# keepalive_count = 5
```

## Next Steps

Once the NUC is configured:

1. **On NUC:** Download Ubuntu ISO and build base image with Packer
2. **On Laptop:** Run Terraform to provision VMs (connects to NUC remotely)
3. **On Laptop:** Use kubectl to manage k3s cluster

See [README.md](../README.md) for deployment instructions.

## Security Considerations

- **SSH-based access:** All remote connections use SSH authentication
- **No TCP exposure:** libvirt TCP port is disabled
- **Firewall:** Consider enabling ufw and allowing only SSH from laptop IP
- **SSH keys:** Use key-based authentication, disable password auth

```bash
# Example: Lock down SSH to key-only auth
sudo vim /etc/ssh/sshd_config
# Set: PasswordAuthentication no
# Set: PubkeyAuthentication yes
sudo systemctl restart ssh
```

## References

- [libvirt Remote Access](https://libvirt.org/remote.html)
- [QEMU/KVM Documentation](https://www.qemu.org/docs/master/)
- [Netplan Bridge Configuration](https://netplan.io/examples#bridging)
