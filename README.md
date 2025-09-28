# Rust + Web 开发环境

基于 `rustlang/rust:nightly` 的 Rust + Node.js 开发环境。

## 构建和使用

```bash
# 构建镜像
./update.sh

# 构建并推送到 Docker Hub
./update.sh -p

# 压缩镜像层
./update.sh -s

# 组合选项
./update.sh -p -s my-image-name

# 运行容器
docker run -it --rm -v $(pwd):/app antvue/rust-web-dev:latest
```

## 预装工具

- Rust (nightly) + cargo + clippy + rustfmt + cargo-watch + wasm-pack
- Node.js (LTS) + npm + pnpm + bun + tsx

## 端口

- 3000, 8000, 8080
