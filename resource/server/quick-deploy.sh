#!/bin/bash
# ========================================
# 服务器端一键部署命令
# 适用于 x86 Linux 服务器
# ========================================

# 1. 安装 Docker（如果未安装）
if ! command -v docker &> /dev/null; then
    echo "正在安装 Docker..."
    curl -fsSL https://get.docker.com | bash
    sudo systemctl start docker
    sudo systemctl enable docker
fi

# 2. 克隆项目并部署
cd /opt
git clone https://your-repo/mamababa-stories.git mamababa-stories 2>/dev/null || true
cd mamababa-stories/server

# 3. 配置环境变量
cp .env.example .env
# 编辑 .env 修改密码
# vim .env

# 4. 部署
bash deploy.sh