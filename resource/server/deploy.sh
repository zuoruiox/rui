#!/bin/bash
#
# 爸爸妈妈讲故事 - 服务端部署脚本
# 适用于 x86 Linux 服务器（CentOS / Ubuntu / Debian）
#
# 使用方法:
#   1. 将此仓库复制到服务器
#   2. cd server
#   3. bash deploy.sh
#
# 可选参数:
#   bash deploy.sh build    - 仅构建镜像
#   bash deploy.sh start    - 启动服务
#   bash deploy.sh stop     - 停止服务
#   bash deploy.sh restart  - 重启服务
#   bash deploy.sh logs     - 查看日志
#   bash deploy.sh status   - 查看状态
#   bash deploy.sh update   - 更新并重新部署
#   bash deploy.sh backup   - 备份数据库和上传文件
#

set -e

# ========== 配置 ==========
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTAINER_NAME="mamababa-server"
COMPOSE_FILE="${PROJECT_DIR}/docker-compose.yml"
ENV_FILE="${PROJECT_DIR}/.env"
BACKUP_DIR="${PROJECT_DIR}/../backups"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
step()  { echo -e "${BLUE}[STEP]${NC}  $1"; }

# ========== 检查依赖 ==========
check_deps() {
    step "检查运行环境..."

    if ! command -v docker &> /dev/null; then
        error "Docker 未安装，请先安装 Docker"
        echo ""
        echo "  CentOS:"
        echo "    sudo yum install -y yum-utils"
        echo "    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo"
        echo "    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin"
        echo "    sudo systemctl start docker"
        echo "    sudo systemctl enable docker"
        echo ""
        echo "  Ubuntu/Debian:"
        echo "    sudo apt update"
        echo "    sudo apt install -y docker.io docker-compose-v2"
        echo "    sudo systemctl start docker"
        echo "    sudo systemctl enable docker"
        echo ""
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        error "Docker Compose 未安装，请先安装"
        exit 1
    fi

    # 检测是否使用 docker compose 子命令
    if docker compose version &> /dev/null 2>&1; then
        DOCKER_COMPOSE="docker compose"
    else
        DOCKER_COMPOSE="docker-compose"
    fi

    info "Docker: $(docker --version)"
    info "Compose: $($DOCKER_COMPOSE version --short 2>/dev/null || echo 'OK')"
    info "系统架构: $(uname -m)"
}

# ========== 初始化配置 ==========
init_config() {
    step "初始化配置文件..."

    if [ ! -f "$ENV_FILE" ]; then
        if [ -f "${PROJECT_DIR}/.env.example" ]; then
            cp "${PROJECT_DIR}/.env.example" "$ENV_FILE"
            warn ".env 文件已创建，请编辑修改密码等敏感配置"
            warn "  vim ${ENV_FILE}"
        else
            error ".env.example 文件不存在"
            exit 1
        fi
    else
        info ".env 文件已存在，跳过创建"
    fi

    # 创建数据目录
    mkdir -p "${PROJECT_DIR}/data"
    mkdir -p "${PROJECT_DIR}/uploads/audio"
    mkdir -p "${PROJECT_DIR}/uploads/recordings"
    mkdir -p "${PROJECT_DIR}/uploads/voices"
    mkdir -p "${PROJECT_DIR}/uploads/avatars"
    mkdir -p "${PROJECT_DIR}/uploads/covers"
    mkdir -p "${PROJECT_DIR}/uploads/subtitles"
    info "数据目录已就绪"
}

# ========== 构建镜像 ==========
build() {
    step "构建 Docker 镜像（x86 平台）..."
    cd "$PROJECT_DIR"
    $DOCKER_COMPOSE build --no-cache
    info "镜像构建完成"
}

# ========== 启动服务 ==========
start() {
    step "启动服务..."
    cd "$PROJECT_DIR"
    $DOCKER_COMPOSE up -d
    info "服务已启动"

    # 等待健康检查通过
    echo ""
    info "等待服务就绪..."
    for i in $(seq 1 30); do
        if curl -s http://localhost:${PORT:-9999}/health > /dev/null 2>&1; then
            info "服务就绪！"
            break
        fi
        sleep 2
        echo -n "."
    done
    echo ""

    show_info
}

# ========== 停止服务 ==========
stop() {
    step "停止服务..."
    cd "$PROJECT_DIR"
    $DOCKER_COMPOSE down
    info "服务已停止"
}

# ========== 重启服务 ==========
restart() {
    step "重启服务..."
    cd "$PROJECT_DIR"
    $DOCKER_COMPOSE restart
    info "服务已重启"
}

# ========== 查看日志 ==========
logs() {
    cd "$PROJECT_DIR"
    $DOCKER_COMPOSE logs -f --tail=100
}

# ========== 查看状态 ==========
status() {
    cd "$PROJECT_DIR"
    $DOCKER_COMPOSE ps
    echo ""
    echo "--- 健康检查 ---"
    if curl -s http://localhost:${PORT:-9999}/health > /dev/null 2>&1; then
        info "服务运行正常"
    else
        warn "服务可能未就绪，请稍后重试"
    fi
}

# ========== 更新部署 ==========
update() {
    step "更新部署..."

    # 先备份
    backup

    # 拉取最新代码（如果使用 git）
    if [ -d "${PROJECT_DIR}/../.git" ]; then
        info "拉取最新代码..."
        cd "${PROJECT_DIR}/.."
        git pull
    fi

    # 重新构建并启动
    build
    stop
    start
}

# ========== 备份 ==========
backup() {
    step "备份数据..."
    BACKUP_NAME="mamababa_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    mkdir -p "$BACKUP_DIR"

    cd "$PROJECT_DIR"

    # 从运行中的容器备份数据库（bind mount 挂载到 ./data）
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        # 容器运行中，从容器内复制数据库
        TMP_DIR=$(mktemp -d)
        docker cp "${CONTAINER_NAME}:/app/data/prod.db" "$TMP_DIR/prod.db" 2>/dev/null || true
        docker cp "${CONTAINER_NAME}:/app/data/dev.db" "$TMP_DIR/dev.db" 2>/dev/null || true
        docker cp "${CONTAINER_NAME}:/app/uploads" "$TMP_DIR/uploads" 2>/dev/null || true
        if [ -f "$TMP_DIR/prod.db" ] || [ -f "$TMP_DIR/dev.db" ]; then
            tar -czf "${BACKUP_DIR}/${BACKUP_NAME}" -C "$TMP_DIR" . 2>/dev/null || true
            rm -rf "$TMP_DIR"
            info "备份完成: ${BACKUP_DIR}/${BACKUP_NAME}"
            info "备份大小: $(du -h ${BACKUP_DIR}/${BACKUP_NAME} | cut -f1)"
        else
            warn "容器内未找到数据库文件"
        fi
    elif [ -d "data" ] && ls data/*.db >/dev/null 2>&1; then
        # 容器未运行，直接从本地挂载目录备份
        tar -czf "${BACKUP_DIR}/${BACKUP_NAME}" data/ uploads/ 2>/dev/null || true
        info "备份完成（本地数据）: ${BACKUP_DIR}/${BACKUP_NAME}"
    else
        warn "暂无数据需要备份"
    fi
}

# ========== 显示信息 ==========
show_info() {
    PORT=${PORT:-9999}
    echo ""
    echo "=========================================="
    echo "  爸爸妈妈讲故事 - 服务端"
    echo "=========================================="
    echo ""
    echo "  管理后台:  http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'localhost'):${PORT}/admin"
    echo "  API 地址:  http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'localhost'):${PORT}/api"
    echo ""
    echo "  常用命令:"
    echo "    bash deploy.sh logs    - 查看日志"
    echo "    bash deploy.sh status  - 查看状态"
    echo "    bash deploy.sh restart - 重启服务"
    echo "    bash deploy.sh backup  - 备份数据"
    echo "    bash deploy.sh stop    - 停止服务"
    echo ""
    echo "=========================================="
}

# ========== 主入口 ==========
main() {
    check_deps

    case "${1:-deploy}" in
        build)
            build
            ;;
        start)
            start
            ;;
        stop)
            stop
            ;;
        restart)
            restart
            ;;
        logs)
            logs
            ;;
        status)
            status
            ;;
        update)
            update
            ;;
        backup)
            backup
            ;;
        deploy)
            init_config
            build
            stop 2>/dev/null || true
            start
            ;;
        *)
            echo "用法: bash deploy.sh [命令]"
            echo ""
            echo "命令:"
            echo "  deploy    完整部署（默认）: 构建 + 启动"
            echo "  build     仅构建镜像"
            echo "  start     启动服务"
            echo "  stop      停止服务"
            echo "  restart   重启服务"
            echo "  logs      查看日志"
            echo "  status    查看状态"
            echo "  update    更新并重新部署"
            echo "  backup    备份数据库和上传文件"
            echo ""
            exit 1
            ;;
    esac
}

main "$@"