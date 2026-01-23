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
  - path: /etc/systemd/system/k3s-agent.service.d/override.conf
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

# Install k3s agent
runcmd:
  - |
    # Find the primary network interface (not lo)
    echo "Finding primary network interface..."
    PRIMARY_IF=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [ -z "$PRIMARY_IF" ]; then
      # Fallback: find first non-loopback interface with an IP
      PRIMARY_IF=$(ip -o link show | grep -v "lo:" | head -n1 | awk -F': ' '{print $2}')
    fi
    echo "Using interface: $PRIMARY_IF"
    
    # Wait for network interface to have an IP
    echo "Waiting for network interface to have IP..."
    for i in {1..30}; do
      if ip addr show "$PRIMARY_IF" | grep -q "inet "; then
        echo "Network interface has IP"
        break
      fi
      echo "Attempt $i: No IP yet..."
      sleep 2
    done
    
    # Wait for default route
    echo "Waiting for default route..."
    for i in {1..30}; do
      if ip route | grep -q "default"; then
        echo "Default route exists"
        break
      fi
      echo "Attempt $i: No default route yet..."
      sleep 2
    done
    
    # Wait for DNS resolution (multiple DNS servers)
    echo "Waiting for DNS resolution..."
    for i in {1..60}; do
      if nslookup get.k3s.io 8.8.8.8 &>/dev/null || \
         nslookup get.k3s.io 1.1.1.1 &>/dev/null; then
        echo "DNS resolution working"
        break
      fi
      echo "Attempt $i: DNS not ready..."
      sleep 2
    done
    
    # Final connectivity test to k3s download site
    echo "Testing connectivity to get.k3s.io..."
    if ! curl -sSf -m 10 https://get.k3s.io >/dev/null; then
      echo "ERROR: Cannot reach get.k3s.io - check network connectivity"
      exit 1
    fi
    
    echo "Network is ready"
    
    # Wait for control plane to be ready
    echo "Waiting for control plane at ${control_plane_ip}..."
    for i in {1..60}; do
      if curl -sSf -k -m 5 https://${control_plane_ip}:6443/ping &>/dev/null; then
        echo "Control plane is ready"
        break
      fi
      echo "Attempt $i: Control plane not ready..."
      sleep 10
    done
    
    echo "Installing k3s agent..."
    
    # Install k3s agent
    curl -sfL https://get.k3s.io | \
      INSTALL_K3S_VERSION="${k3s_version}" \
      K3S_TOKEN="${k3s_token}" \
      K3S_URL="https://${control_plane_ip}:6443" \
      sh -s - agent \
      --node-name=${hostname}
    
    echo "k3s worker node joined cluster"

final_message: "k3s worker node ${hostname} is ready after $UPTIME seconds"