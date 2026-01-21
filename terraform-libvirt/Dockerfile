FROM hashicorp/terraform:latest

# Install mkisofs (genisoimage) for cloud-init ISO creation
RUN apk add --no-cache xorriso

ENTRYPOINT ["terraform"]