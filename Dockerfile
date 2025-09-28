# Use Rust nightly as base image
FROM rustlang/rust:nightly

# Install required system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    ca-certificates \
    gnupg \
    lsb-release \
    xz-utils \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Set shell to use bash for better compatibility
SHELL ["/bin/bash", "-c"]

# Install Node.js v22.18.0 manually
ENV NODE_VERSION=22.18.0
RUN wget -O node.tar.xz https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz --no-check-certificate \
    && tar -xJf node.tar.xz -C /usr/local --strip-components=1 \
    && rm node.tar.xz \
    && node --version \
    && npm --version

# Configure npm with default registry
RUN npm config set registry https://registry.npmjs.org/ \
    && npm config set strict-ssl false

# Install pnpm directly from GitHub releases to avoid npm registry issues
RUN wget -O pnpm.js https://github.com/pnpm/pnpm/releases/latest/download/pnpm-linux-x64 --no-check-certificate \
    && chmod +x pnpm.js \
    && mv pnpm.js /usr/local/bin/pnpm \
    && pnpm --version

# Install bun directly from GitHub releases
RUN wget -O bun.zip https://github.com/oven-sh/bun/releases/latest/download/bun-linux-x64.zip --no-check-certificate \
    && unzip bun.zip \
    && chmod +x bun-linux-x64/bun \
    && mv bun-linux-x64/bun /usr/local/bin/bun \
    && rm -rf bun.zip bun-linux-x64 \
    && bun --version

# Set up pnpm and configure registry (using default for now due to network issues)
RUN export SHELL=/bin/bash \
    && pnpm config set registry https://registry.npmjs.org/ \
    && pnpm config set store-dir /root/.pnpm-store \
    && mkdir -p /root/.local/share/pnpm \
    && pnpm config set global-bin-dir /root/.local/share/pnpm \
    && pnpm setup || true

# Install tsx globally using npm (simpler and more reliable)
# Note: tsx can be installed later via pnpm add -g tsx if needed
RUN npm install -g tsx --timeout=120000 || echo "tsx installation failed, can be installed manually later"

# Add pnpm to PATH for all future commands
ENV PATH="/root/.local/share/pnpm:${PATH}"

# Verify core installations (skip tsx if it failed)
RUN echo "=== Verification ===" \
    && rustc --version \
    && cargo --version \
    && node --version \
    && npm --version \
    && pnpm --version \
    && bun --version \
    && (tsx --version || echo "tsx not installed, use: npm install -g tsx")

# Set working directory
WORKDIR /app

# Create a simple verification script
RUN echo '#!/bin/bash' > /usr/local/bin/verify-setup \
    && echo 'echo "=== Environment Setup Verification ==="' >> /usr/local/bin/verify-setup \
    && echo 'echo "Rust version: $(rustc --version)"' >> /usr/local/bin/verify-setup \
    && echo 'echo "Cargo version: $(cargo --version)"' >> /usr/local/bin/verify-setup \
    && echo 'echo "Node.js version: $(node --version)"' >> /usr/local/bin/verify-setup \
    && echo 'echo "npm version: $(npm --version)"' >> /usr/local/bin/verify-setup \
    && echo 'echo "pnpm version: $(pnpm --version)"' >> /usr/local/bin/verify-setup \
    && echo 'echo "bun version: $(bun --version)"' >> /usr/local/bin/verify-setup \
    && echo 'echo -n "tsx version: "; tsx --version || echo "not installed (install with: npm install -g tsx)"' >> /usr/local/bin/verify-setup \
    && echo 'echo "All core tools are ready for Rust web development!"' >> /usr/local/bin/verify-setup \
    && chmod +x /usr/local/bin/verify-setup

# Default command
CMD ["/bin/bash"]