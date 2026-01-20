variable "ubuntu_version" {
  type        = string
  description = "Ubuntu version to use"
  default     = "24.04"
}

variable "ubuntu_iso_url" {
  type        = string
  description = "URL or local path for Ubuntu server ISO"
  default     = "https://releases.ubuntu.com/24.04/ubuntu-24.04.1-live-server-amd64.iso"
  # For local ISO, use: file:///path/to/ubuntu-24.04.1-live-server-amd64.iso
}

variable "ubuntu_iso_checksum" {
  type        = string
  description = "Checksum for Ubuntu ISO (use 'none' to skip verification for local files)"
  default     = "sha256:e240e4b801f098faa91c8223e11e4aa7a9d5e35c02cc1d9a0d5a6e0fc0c8b1b1"
  # For local ISO without checksum: use "none"
}

variable "disk_size" {
  type        = string
  description = "Disk size for VM image"
  default     = "80G"
}

variable "memory" {
  type        = string
  description = "Memory for Packer build VM"
  default     = "2048"
}

variable "cpus" {
  type        = string
  description = "CPUs for Packer build VM"
  default     = "2"
}

variable "headless" {
  type        = bool
  description = "Run without GUI"
  default     = true
}

variable "output_directory" {
  type        = string
  description = "Directory for build output"
  default     = "output-qemu"
}

variable "vm_name" {
  type        = string
  description = "Name for output image"
  default     = "k3s-node-ubuntu-24.04"
}

variable "libvirt_pool_path" {
  type        = string
  description = "Path to libvirt storage pool"
  default     = env("HOME")
}
