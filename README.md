# rust-web
rust web build

## Docker Environment

This repository includes a comprehensive Dockerfile for Rust web development with Node.js toolchain.

### Features

The Docker image is based on `rustlang/rust:nightly` and includes:

- **Rust nightly toolchain** (rustc and cargo)
- **Node.js v22.18.0** (LTS version)
- **npm** (Node package manager)
- **pnpm** (Fast, disk space efficient package manager)
- **bun** (JavaScript runtime and package manager)
- **tsx** (TypeScript executor)

### Usage

#### Build the Docker image:
```bash
docker build -t rust-web .
```

#### Run the container:
```bash
docker run -it --rm rust-web
```

#### Verify the setup:
```bash
docker run --rm rust-web verify-setup
```

### Package Managers Configuration

The image comes preconfigured with:
- npm registry: https://registry.npmjs.org/ 
- SSL certificate verification disabled for compatibility
- pnpm global binary directory set up

### Manual Installation Commands

If you need to replicate the setup manually, here are the key commands used:

```bash
# Install Node.js v22.18.0
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
source ~/.bashrc
nvm ls-remote
nvm install v22.18.0
nvm use v22.18.0

# Configure npm registry (for Chinese users)
npm config set registry https://registry.npmmirror.com

# Install global packages
npm install -g bun pnpm

# Setup pnpm
pnpm setup
source ~/.bashrc

# Install tsx
pnpm add -g tsx
```

### Development Workflow

1. Start the container with your project mounted:
   ```bash
   docker run -it --rm -v $(pwd):/app rust-web
   ```

2. Use any of the available tools:
   ```bash
   # Rust development
   cargo new my-project
   cargo build
   cargo run
   
   # Node.js development
   npm init
   npm install
   
   # Using pnpm
   pnpm init
   pnpm install
   
   # Using bun
   bun init
   bun install
   
   # TypeScript execution
   tsx my-script.ts
   ```
