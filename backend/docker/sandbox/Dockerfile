# Gitu Sandbox Environment
# Restricted environment for executing user shell commands
# Based on Node.js to support npm/node commands as requested

FROM node:20-alpine

# Install basic tools
RUN apk add --no-cache \
    bash \
    git \
    curl \
    jq \
    coreutils

# Create a workspace directory
WORKDIR /workspace

# Create a non-root user (node user already exists in node image)
# We will use the 'node' user for execution
USER node

# Set entrypoint to sh
ENTRYPOINT ["/bin/sh", "-c"]
