locals {
  ssh_public_key = file(pathexpand(var.ssh_public_key_path))
  k3s_token      = var.k3s_token != "" ? var.k3s_token : random_password.k3s_token.result
  k3s_version    = var.k3s_version != "" ? var.k3s_version : "stable"
}

# Generate random token for k3s cluster if not provided
resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

# Base volume (used as backing image for all VMs)
resource "libvirt_volume" "base" {
  name   = "k3s-node-ubuntu-24.04.qcow2"  # Use the existing volume name
  pool   = var.libvirt_pool
  format = "qcow2"
  # NO source - tell Terraform to adopt the existing volume
}

# Control Plane Nodes
resource "libvirt_volume" "control_plane" {
  count          = var.control_plane_count
  name           = "k3s-cp-${format("%02d", count.index + 1)}.qcow2"
  pool           = var.libvirt_pool
  base_volume_id = libvirt_volume.base.id
  size           = var.disk_size
  format         = "qcow2"
}

resource "libvirt_cloudinit_disk" "control_plane" {
  count     = var.control_plane_count
  name      = "k3s-cp-${format("%02d", count.index + 1)}-cloudinit.iso"
  pool      = var.libvirt_pool
  user_data = templatefile("${path.module}/cloud-init/k3s-cp.yml.tpl", {
    hostname       = "k3s-cp-${format("%02d", count.index + 1)}"
    ssh_public_key = local.ssh_public_key
    k3s_version    = local.k3s_version
    k3s_token      = local.k3s_token
    node_index     = count.index
  })
}

resource "libvirt_domain" "control_plane" {
  count  = var.control_plane_count
  name   = "k3s-cp-${format("%02d", count.index + 1)}"
  memory = var.control_plane_memory
  vcpu   = var.control_plane_vcpu

  cloudinit = libvirt_cloudinit_disk.control_plane[count.index].id

  disk {
    volume_id = libvirt_volume.control_plane[count.index].id
  }

  network_interface {
    network_name   = var.libvirt_network
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }

  qemu_agent = true
}

# Worker Nodes
resource "libvirt_volume" "worker" {
  count          = var.worker_count
  name           = "k3s-worker-${format("%02d", count.index + 1)}.qcow2"
  pool           = var.libvirt_pool
  base_volume_id = libvirt_volume.base.id
  size           = var.disk_size
  format         = "qcow2"
}

resource "libvirt_cloudinit_disk" "worker" {
  count     = var.worker_count
  name      = "k3s-worker-${format("%02d", count.index + 1)}-cloudinit.iso"
  pool      = var.libvirt_pool
  user_data = templatefile("${path.module}/cloud-init/k3s-worker.yml.tpl", {
    hostname         = "k3s-worker-${format("%02d", count.index + 1)}"
    ssh_public_key   = local.ssh_public_key
    k3s_version      = local.k3s_version
    k3s_token        = local.k3s_token
    control_plane_ip = libvirt_domain.control_plane[0].network_interface[0].addresses[0]
  })
}

resource "libvirt_domain" "worker" {
  count  = var.worker_count
  name   = "k3s-worker-${format("%02d", count.index + 1)}"
  memory = var.worker_memory
  vcpu   = var.worker_vcpu

  cloudinit = libvirt_cloudinit_disk.worker[count.index].id

  disk {
    volume_id = libvirt_volume.worker[count.index].id
  }

  network_interface {
    network_name   = var.libvirt_network
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }

  qemu_agent = true

  depends_on = [libvirt_domain.control_plane]
}
