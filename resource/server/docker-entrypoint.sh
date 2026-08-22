#!/bin/sh
set -e

DATA_DIR="./data"
PROD_DB="$DATA_DIR/prod.db"
DEV_DB="$DATA_DIR/dev.db"

echo "📦 生成 Prisma Client..."
npx prisma generate

# 确保数据目录存在
mkdir -p "$DATA_DIR"

# 初始化生产数据库
init_db() {
    local db_path="$1"
    local db_name="$2"
    local db_url="file:../$db_path"

    if [ ! -f "$db_path" ] || [ ! -s "$db_path" ]; then
        echo "🆕 初始化 $db_name..."
        # 使用空数据库，prisma db push 会创建表结构
        touch "$db_path"
        echo "✅ $db_name 已创建"
    else
        echo "✅ $db_name 已存在，跳过初始化"
        # 备份现有数据库
        BACKUP_PATH="${db_path}.backup-$(date +%Y%m%d%H%M%S)"
        cp "$db_path" "$BACKUP_PATH"
        echo "💾 已备份 $db_name 到: $BACKUP_PATH"
    fi
}

init_db "$PROD_DB" "生产数据库(prod.db)"
init_db "$DEV_DB" "开发数据库(dev.db)"

echo "🔄 同步数据库结构..."
# 使用生产数据库 URL 执行 db push
DATABASE_URL="file:../$PROD_DB" npx prisma db push

# 检查生产数据库是否为空，如果为空则执行种子数据
USER_COUNT=$(sqlite3 "$PROD_DB" "SELECT COUNT(*) FROM User;" 2>/dev/null || echo "0")
if [ "$USER_COUNT" = "0" ] || [ -z "$USER_COUNT" ]; then
    echo "🌱 生产数据库为空，初始化种子数据..."
    DATABASE_URL="file:../$PROD_DB" node dist/prisma/seed.js
else
    echo "✅ 生产数据库已有数据（${USER_COUNT} 个用户），跳过种子初始化"
fi

# 同步开发数据库结构
echo "🔄 同步开发数据库结构..."
DATABASE_URL="file:../$DEV_DB" npx prisma db push

# 检查开发数据库是否为空，如果为空则执行种子数据
DEV_USER_COUNT=$(sqlite3 "$DEV_DB" "SELECT COUNT(*) FROM User;" 2>/dev/null || echo "0")
if [ "$DEV_USER_COUNT" = "0" ] || [ -z "$DEV_USER_COUNT" ]; then
    echo "🌱 开发数据库为空，初始化种子数据..."
    DATABASE_URL="file:../$DEV_DB" node dist/prisma/seed.js
else
    echo "✅ 开发数据库已有数据（${DEV_USER_COUNT} 个用户），跳过种子初始化"
fi

echo "🚀 启动服务..."
exec node dist/src/index.js
