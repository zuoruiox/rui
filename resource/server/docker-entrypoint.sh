#!/bin/sh
set -e

echo "📦 生成 Prisma Client..."
npx prisma generate

echo "🔄 同步数据库结构..."
npx prisma db push

# 仅在数据库文件不存在（首次部署）时执行种子数据
if [ ! -f "./data/prod.db" ] || [ ! -s "./data/prod.db" ]; then
    echo "🌱 首次部署，初始化种子数据..."
    node dist/prisma/seed.js
else
    echo "✅ 数据库已存在，跳过种子初始化"
fi

echo "🚀 启动服务..."
exec node dist/src/index.js
