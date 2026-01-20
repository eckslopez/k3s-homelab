#!/bin/bash
# Pre-flight check script for k3s-homelab
# Validates libvirt setup before running Packer/Terraform

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== k3s Home Lab Pre-flight Checks ==="
echo ""

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${RED}✗ Not running on Linux${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Linux detected${NC}"

# Check if libvirtd is running
if ! systemctl is-active --quiet libvirtd; then
    echo -e "${RED}✗ libvirtd is not running${NC}"
    echo "  Run: sudo systemctl start libvirtd"
    exit 1
fi
echo -e "${GREEN}✓ libvirtd is running${NC}"

# Check for required commands
for cmd in virsh packer terraform; do
    if ! command -v $cmd &> /dev/null; then
        echo -e "${RED}✗ $cmd not found${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ $cmd installed${NC}"
done

# Check libvirt networks
echo ""
echo "Available libvirt networks:"
virsh net-list --all | tail -n +3

NETWORK_COUNT=$(virsh net-list --all | tail -n +3 | grep -c .)
if [ $NETWORK_COUNT -eq 0 ]; then
    echo -e "${RED}✗ No libvirt networks found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Found $NETWORK_COUNT libvirt network(s)${NC}"

# Check libvirt storage pools
echo ""
echo "Available libvirt storage pools:"
virsh pool-list --all | tail -n +3

POOL_COUNT=$(virsh pool-list --all | tail -n +3 | grep -c .)
if [ $POOL_COUNT -eq 0 ]; then
    echo -e "${RED}✗ No libvirt storage pools found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Found $POOL_COUNT storage pool(s)${NC}"

# Check available resources
echo ""
TOTAL_CPU=$(nproc)
TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
TOTAL_DISK=$(df -h ~ | awk 'NR==2{print $4}')

echo "System Resources:"
echo "  CPU Cores: $TOTAL_CPU"
echo "  Memory: ${TOTAL_MEM}GB"
echo "  Available Disk: $TOTAL_DISK"

if [ $TOTAL_CPU -lt 18 ]; then
    echo -e "${YELLOW}⚠ Warning: Less than 18 CPU cores (have $TOTAL_CPU). Cluster may be slow.${NC}"
fi

if [ $TOTAL_MEM -lt 32 ]; then
    echo -e "${YELLOW}⚠ Warning: Less than 32GB RAM (have ${TOTAL_MEM}GB). May need to reduce VM specs.${NC}"
fi

# Check SSH key
echo ""
if [ -f ~/.ssh/id_rsa.pub ]; then
    echo -e "${GREEN}✓ SSH public key found at ~/.ssh/id_rsa.pub${NC}"
elif [ -f ~/.ssh/id_ed25519.pub ]; then
    echo -e "${GREEN}✓ SSH public key found at ~/.ssh/id_ed25519.pub${NC}"
    echo -e "${YELLOW}  Note: Update terraform.tfvars to use id_ed25519.pub${NC}"
else
    echo -e "${YELLOW}⚠ No SSH key found. Generate one with: ssh-keygen -t ed25519${NC}"
fi

# Check if terraform.tfvars exists
echo ""
if [ -f terraform-libvirt/terraform.tfvars ]; then
    echo -e "${GREEN}✓ terraform.tfvars configured${NC}"
else
    echo -e "${YELLOW}⚠ terraform.tfvars not found${NC}"
    echo "  Copy the example: cp terraform-libvirt/terraform.tfvars.example terraform-libvirt/terraform.tfvars"
fi

echo ""
echo "=== Pre-flight checks complete ==="
echo ""
echo "Next steps:"
echo "  1. Review/update terraform-libvirt/terraform.tfvars"
echo "  2. Run: make image"
echo "  3. Run: make cluster-up"
