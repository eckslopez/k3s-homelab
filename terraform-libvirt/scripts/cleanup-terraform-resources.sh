#!/bin/bash
# cleanup-terraform-state.sh
# Run this from your laptop where you execute terraform commands

set -e

echo "=== Removing resources from Terraform state ==="

docker compose run --rm terraform state rm 'libvirt_domain.control_plane[0]' 2>/dev/null || true
docker compose run --rm terraform state rm 'libvirt_domain.worker[0]' 2>/dev/null || true
docker compose run --rm terraform state rm 'libvirt_domain.worker[1]' 2>/dev/null || true
docker compose run --rm terraform state rm 'libvirt_volume.control_plane[0]' 2>/dev/null || true
docker compose run --rm terraform state rm 'libvirt_volume.worker[0]' 2>/dev/null || true
docker compose run --rm terraform state rm 'libvirt_volume.worker[1]' 2>/dev/null || true
docker compose run --rm terraform state rm 'libvirt_cloudinit_disk.control_plane[0]' 2>/dev/null || true
docker compose run --rm terraform state rm 'libvirt_cloudinit_disk.worker[0]' 2>/dev/null || true
docker compose run --rm terraform state rm 'libvirt_cloudinit_disk.worker[1]' 2>/dev/null || true

echo "=== Terraform state cleanup complete ==="