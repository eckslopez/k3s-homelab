.PHONY: help image cluster-up cluster-down clean validate

# Colors for output
GREEN  := \033[0;32m
YELLOW := \033[0;33m
RED    := \033[0;31m
NC     := \033[0m # No Color

# Paths
PACKER_DIR := packer/k3s-node
TERRAFORM_DIR := terraform-libvirt

help: ## Show this help message
	@echo "$(GREEN)k3s Home Lab - Make Targets$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""

validate: ## Validate Packer and Terraform configurations
	@echo "$(GREEN)Validating Packer template...$(NC)"
	cd $(PACKER_DIR) && packer validate .
	@echo "$(GREEN)Validating Terraform configuration...$(NC)"
	cd $(TERRAFORM_DIR) && terraform init -backend=false && terraform validate
	@echo "$(GREEN)✓ All configurations valid$(NC)"

image: ## Build base VM image with Packer
	@echo "$(GREEN)Building k3s node image with Packer...$(NC)"
	cd $(PACKER_DIR) && packer build .
	@echo "$(GREEN)✓ Image build complete$(NC)"

cluster-up: ## Deploy k3s cluster with Terraform
	@echo "$(GREEN)Deploying k3s cluster...$(NC)"
	@if [ ! -f $(TERRAFORM_DIR)/terraform.tfvars ]; then \
		echo "$(RED)Error: terraform.tfvars not found$(NC)"; \
		echo "$(YELLOW)Copy terraform.tfvars.example and configure your settings:$(NC)"; \
		echo "  cp $(TERRAFORM_DIR)/terraform.tfvars.example $(TERRAFORM_DIR)/terraform.tfvars"; \
		exit 1; \
	fi
	cd $(TERRAFORM_DIR) && terraform init
	cd $(TERRAFORM_DIR) && terraform plan -out=tfplan
	cd $(TERRAFORM_DIR) && terraform apply tfplan
	@echo "$(GREEN)✓ Cluster deployed successfully$(NC)"
	@echo ""
	@echo "$(YELLOW)Access your cluster:$(NC)"
	@cd $(TERRAFORM_DIR) && terraform output

cluster-down: ## Destroy k3s cluster (keeps base image)
	@echo "$(YELLOW)Destroying k3s cluster...$(NC)"
	cd $(TERRAFORM_DIR) && terraform destroy
	@echo "$(GREEN)✓ Cluster destroyed$(NC)"

clean: cluster-down ## Remove cluster and base image
	@echo "$(YELLOW)Removing base image...$(NC)"
	@rm -f ~/libvirt_images/k3s-node-ubuntu-24.04.qcow2
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

cluster-status: ## Show cluster status
	@echo "$(GREEN)Cluster Status:$(NC)"
	@cd $(TERRAFORM_DIR) && terraform show | grep -A 2 "network_interfaces"
