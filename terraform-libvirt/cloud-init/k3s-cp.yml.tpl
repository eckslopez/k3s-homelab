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

# Explicitly configure SSH daemon
write_files:
  - path: /etc/ssh/sshd_config.d/99-cloud-init-hardening.conf
    content: |
      # Cloud-init SSH hardening
      PasswordAuthentication no
      PubkeyAuthentication yes
      PermitRootLogin no
      ChallengeResponseAuthentication no
      UsePAM yes
    permissions: '0644'
  - path: /etc/systemd/system/k3s.service.d/override.conf
    content: |
      [Service]
      Restart=always
      RestartSec=5s

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

# Install k3s server
runcmd:
  - |
    # Restart SSH to apply config
    systemctl restart sshd
    
    # Wait for network
    until ping -c1 google.com &>/dev/null; do
      echo "Waiting for network..."
      sleep 5
    done
    
    # Install k3s server
    curl -sfL https://get.k3s.io | \
      INSTALL_K3S_VERSION="${k3s_version}" \
      K3S_TOKEN="${k3s_token}" \
      sh -s - server \
      --write-kubeconfig-mode 644 \
      --disable=traefik \
      --node-name=${hostname}
    
    # Wait for k3s to be ready
    until kubectl get nodes &>/dev/null; do
      echo "Waiting for k3s..."
      sleep 5
    done
    
    echo "k3s control plane ready"

# Write additional config files

final_message: "k3s control plane node ${hostname} is ready after $UPTIME seconds"
