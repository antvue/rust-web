#!/bin/bash

# 更新脚本 - 获取最新的 NVM LTS 版本并构建 Docker 镜像
# 使用方法: ./update.sh [选项] [镜像名称]
# 选项: -p 推送镜像到 Docker Hub, -h 显示帮助

set -e  # 如果任何命令失败，脚本将退出

# 默认镜像名称
DEFAULT_IMAGE_NAME="antvue/rust-web-dev"
IMAGE_NAME="$DEFAULT_IMAGE_NAME"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查必要的命令是否存在
check_dependencies() {
    echo_info "检查依赖..."
    
    local deps=("curl" "jq" "docker")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo_error "缺少依赖: $dep"
            echo "请安装 $dep 后重新运行脚本"
            exit 1
        fi
    done
    
    echo_success "所有依赖检查通过"
}

# 获取最新的 Node.js LTS 版本（纯数据获取）
fetch_latest_lts_version() {
    local versions_json
    versions_json=$(curl -s https://nodejs.org/dist/index.json)
    
    local latest_lts
    latest_lts=$(echo "$versions_json" | jq -r 'map(select(.lts != false)) | .[0].version')
    
    if [[ -z "$latest_lts" || "$latest_lts" == "null" ]]; then
        return 1
    fi
    
    echo "$latest_lts"
}

# 获取最新的 NVM 版本（纯数据获取）
fetch_latest_nvm_version() {
    local api_response
    api_response=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest)
    
    local latest_nvm_version
    latest_nvm_version=$(echo "$api_response" | jq -r '.tag_name')
    
    if [[ -z "$latest_nvm_version" || "$latest_nvm_version" == "null" ]]; then
        return 1
    fi
    
    echo "$latest_nvm_version"
}

# 拉取最新的 Rust nightly 镜像
pull_rust_image() {
    echo_info "拉取最新的 rustlang/rust:nightly 镜像..."
    
    if docker pull rustlang/rust:nightly; then
        echo_success "成功拉取 rustlang/rust:nightly 镜像"
    else
        echo_error "拉取 Rust 镜像失败"
        exit 1
    fi
}

# 更新 Dockerfile 中的 Node.js 版本和 NVM 版本
update_dockerfile() {
    local node_version="$1"
    local nvm_version="$2"
    
    echo_info "更新 Dockerfile 中的 Node.js 版本为:[ $node_version ]..."
    echo_info "更新 Dockerfile 中的 NVM 版本为:[ $nvm_version ]..."
    
    if [[ ! -f "Dockerfile" ]]; then
        echo_error "未找到 Dockerfile"
        exit 1
    fi
    
    # 备份原始 Dockerfile
    cp Dockerfile Dockerfile.bak
    
    # 更新 Node.js 版本
    sed -i "s/ENV NODE_VERSION=\".*\"/ENV NODE_VERSION=\"$node_version\"/" Dockerfile
    
    # 更新 NVM 版本
    sed -i "s/ENV NVM_VERSION=\".*\"/ENV NVM_VERSION=\"$nvm_version\"/" Dockerfile
    
    echo_success "Dockerfile 已更新"
}

# 构建 Docker 镜像
build_docker_image() {
    local build_args=""
    
    # 如果启用了 squash，添加 --squash 参数
    if [[ "$SQUASH_IMAGE" == "true" ]]; then
        build_args="--squash"
        echo_info "构建 Docker 镜像 (启用压缩): $IMAGE_NAME..."
    else
        echo_info "构建 Docker 镜像: $IMAGE_NAME..."
    fi
    
    if docker build $build_args -t "$IMAGE_NAME:latest" .; then
        echo_success "Docker 镜像构建成功: $IMAGE_NAME:latest"
        
        # 显示镜像大小信息
        local image_size
        image_size=$(docker images "$IMAGE_NAME:latest" --format "table {{.Size}}" | tail -n 1)
        echo_info "镜像大小: $image_size"
    else
        echo_error "Docker 镜像构建失败"
        
        # 恢复原始 Dockerfile
        if [[ -f "Dockerfile.bak" ]]; then
            mv Dockerfile.bak Dockerfile
            echo_warning "已恢复原始 Dockerfile"
        fi
        
        exit 1
    fi
    
    # 清理备份文件
    if [[ -f "Dockerfile.bak" ]]; then
        rm Dockerfile.bak
    fi
}

# 推送 Docker 镜像
push_docker_image() {
    echo_info "推送 Docker 镜像到 Docker Hub: $IMAGE_NAME:latest..."
    
    if docker push "$IMAGE_NAME:latest"; then
        echo_success "Docker 镜像推送成功: $IMAGE_NAME:latest"
    else
        echo_error "Docker 镜像推送失败"
        echo_warning "请确保:"
        echo "1. 已登录 Docker Hub (运行: docker login)"
        echo "2. 有推送到 $IMAGE_NAME 的权限"
        exit 1
    fi
}

# 显示镜像信息
show_image_info() {
    echo_info "Docker 镜像信息:"
    docker images | grep "$IMAGE_NAME" | head -n 1
    
    echo ""
    echo_info "使用以下命令运行容器:"
    echo "docker run -it --rm -v \$(pwd):/app $IMAGE_NAME:latest"
    echo ""
    echo_info "或者以守护进程方式运行:"
    echo "docker run -d --name rust-web-container -p 3000:3000 -p 8000:8000 -v \$(pwd):/app $IMAGE_NAME:latest"
}

# 清理函数
cleanup() {
    if [[ -f "Dockerfile.bak" ]]; then
        echo_warning "清理备份文件..."
        rm Dockerfile.bak
    fi
}

# 设置退出时的清理
trap cleanup EXIT

# 全局变量
PUSH_IMAGE=false
SQUASH_IMAGE=false

# 主函数
main() {
    echo_info "开始更新 Rust + Web 开发环境..."
    echo ""
    
    check_dependencies
    
    echo_info "获取最新的 Node.js LTS 版本..."
    local latest_lts_version
    if latest_lts_version=$(fetch_latest_lts_version); then
        echo_success "最新的 Node.js LTS 版本: $latest_lts_version"
    else
        echo_error "无法获取最新的 LTS 版本"
        exit 1
    fi
    
    echo_info "获取最新的 NVM 版本..."
    local latest_nvm_version
    if latest_nvm_version=$(fetch_latest_nvm_version); then
        echo_success "最新的 NVM 版本: $latest_nvm_version"
    else
        echo_error "无法获取最新的 NVM 版本"
        exit 1
    fi
    
    pull_rust_image
    
    update_dockerfile "$latest_lts_version" "$latest_nvm_version"
    
    build_docker_image
    
    # 如果指定了推送选项，则推送镜像
    if [[ "$PUSH_IMAGE" == "true" ]]; then
        push_docker_image
    fi
    
    show_image_info
    
    echo ""
    echo_success "更新完成！"
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项] [镜像名称]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示此帮助信息"
    echo "  -p, --push     构建完成后推送镜像到 Docker Hub"
    echo "  -s, --squash   压缩镜像层以减少镜像大小"
    echo ""
    echo "参数:"
    echo "  镜像名称       自定义 Docker 镜像名称 (默认: $DEFAULT_IMAGE_NAME)"
    echo ""
    echo "示例:"
    echo "  $0                           # 使用默认镜像名称"
    echo "  $0 $DEFAULT_IMAGE_NAME                  # 使用自定义镜像名称"
    echo "  $0 -p                        # 构建并推送默认镜像"
    echo "  $0 -s                        # 构建压缩镜像"
    echo "  $0 -p -s                     # 构建压缩镜像并推送"
    echo "  $0 -p -s $DEFAULT_IMAGE_NAME            # 构建压缩镜像并推送自定义镜像"
}

# 解析命令行参数
parse_arguments() {
    local image_name=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -p|--push)
                PUSH_IMAGE=true
                shift
                ;;
            -s|--squash)
                SQUASH_IMAGE=true
                shift
                ;;
            -*)
                echo_error "未知选项: $1"
                echo "使用 -h 或 --help 查看帮助信息"
                exit 1
                ;;
            *)
                # 保存最后一个非选项参数作为镜像名称
                image_name="$1"
                shift
                ;;
        esac
    done
    
    # 如果提供了镜像名称，则使用它，否则使用默认值
    if [[ -n "$image_name" ]]; then
        IMAGE_NAME="$image_name"
    fi
}

# 处理命令行参数
parse_arguments "$@"
main