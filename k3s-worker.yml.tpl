#cloud-config
hostname: ${hostname}
fqdn: ${hostname}.local

users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    shell: /bin/bash
    ssh_authorized_keys:
      - ${ssh_public_key}

# Disable password authentication
ssh_pwauth: false

# Configure timezone
timezone: UTC

# System updates
package_update: true
package_upgrade: true

# Additional packages
packages:
  - curl
  - vim
  - htop
  - net-tools

# Install k3s agent
runcmd:
  - |
    # Wait for network
    until ping -c1 google.com &>/dev/null; do
      echo "Waiting for network..."
      sleep 5
    done
    
    # Wait for control plane to be ready
    echo "Waiting for control plane at ${control_plane_ip}..."
    until curl -k https://${control_plane_ip}:6443/ping &>/dev/null; do
      echo "Control plane not ready, waiting..."
      sleep 10
    done
    
    # Install k3s agent
    curl -sfL https://get.k3s.io | \
      INSTALL_K3S_VERSION="${k3s_version}" \
      K3S_TOKEN="${k3s_token}" \
      K3S_URL="https://${control_plane_ip}:6443" \
      sh -s - agent \
      --node-name=${hostname}
    
    echo "k3s worker node joined cluster"

# Enable k3s-agent service
write_files:
  - path: /etc/systemd/system/k3s-agent.service.d/override.conf
    content: |
      [Service]
      Restart=always
      RestartSec=5s

final_message: "k3s worker node ${hostname} is ready after $UPTIME seconds"
