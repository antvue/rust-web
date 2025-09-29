# 使用 Rust nightly 作为基础镜像
FROM rustlang/rust:nightly

# 配置中国国内 apt 镜像源（阿里云镜像）
RUN if [ -f /etc/apt/sources.list ]; then \
        sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list && \
        sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list; \
    fi && \
    if [ -d /etc/apt/sources.list.d ]; then \
        find /etc/apt/sources.list.d -name "*.sources" -exec sed -i 's/deb.debian.org/mirrors.aliyun.com/g' {} \; && \
        find /etc/apt/sources.list.d -name "*.sources" -exec sed -i 's/security.debian.org/mirrors.aliyun.com/g' {} \; && \
        find /etc/apt/sources.list.d -name "*.list" -exec sed -i 's/deb.debian.org/mirrors.aliyun.com/g' {} \; && \
        find /etc/apt/sources.list.d -name "*.list" -exec sed -i 's/security.debian.org/mirrors.aliyun.com/g' {} \;; \
    fi

# 更新系统包
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    pkg-config \
    libssl-dev \
    ca-certificates \
    sudo \
    vim \
    && rm -rf /var/lib/apt/lists/*

# 创建 dev 用户并配置 sudo 免密码
RUN groupadd -r dev && useradd -r -g dev -m -d /home/dev -s /bin/bash dev \
    && echo 'dev ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV NVM_DIR="/home/dev/.nvm"
ENV NVM_VERSION="v0.40.3"
ENV NODE_VERSION="v22.20.0"
ENV PATH="$NVM_DIR/versions/node/$NODE_VERSION/bin:$PATH"

# 切换到 dev 用户
USER dev
WORKDIR /home/dev

# 安装 NVM 和 Node.js
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install $NODE_VERSION \
    && nvm use $NODE_VERSION \
    && nvm alias default $NODE_VERSION

# 配置 npm 镜像源
RUN . "$NVM_DIR/nvm.sh" && npm config set registry https://registry.npmmirror.com

# 安装全局 npm 包
RUN . "$NVM_DIR/nvm.sh" \
    && npm install -g bun pnpm \
    && SHELL=/bin/bash pnpm setup \
    && export PNPM_HOME="/home/dev/.local/share/pnpm" \
    && export PATH="$PNPM_HOME:$PATH" \
    && pnpm add -g tsx

# 安装 Rust 组件
RUN rustup component add rustfmt clippy llvm-tools-preview --toolchain nightly-x86_64-unknown-linux-gnu

# 安装 Rust Web 开发相关的工具
RUN cargo install cargo-watch wasm-pack cargo-expand cargo-workspace junitify cargo-nextest cargo-llvm-cov

# 创建工作目录并设置权限
USER root
RUN mkdir -p /app && chown -R dev:dev /app
USER dev
WORKDIR /builds

# 复制项目文件
COPY --chown=dev:dev . .

# 设置 shell 为 bash 以确保环境变量正确加载
SHELL ["/bin/bash", "-c"]

# 确保 NVM 在每次启动时都可用
RUN echo 'export NVM_DIR="/home/dev/.nvm"' >> /home/dev/.bashrc \
    && echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /home/dev/.bashrc \
    && echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> /home/dev/.bashrc \
    && echo 'export PATH="$NVM_DIR/versions/node/$NODE_VERSION/bin:$PATH"' >> /home/dev/.bashrc

# 暴露常用端口
EXPOSE 3000 8000 8080

# 默认命令
CMD ["/bin/bash"]