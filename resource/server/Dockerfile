# ========== 构建阶段 ==========
# 指定 linux/amd64 平台，确保在 x86 服务器上正常运行
# 使用 Debian 基础镜像（非 Alpine），避免 musl/OpenSSL 兼容性问题
FROM --platform=linux/amd64 node:20-slim AS builder

WORKDIR /app

# 安装构建依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# 先复制依赖文件，利用 Docker 缓存层
COPY package*.json ./
RUN npm ci

# 复制源码
COPY tsconfig.json ./
COPY prisma ./prisma/
COPY src ./src/
COPY public ./public/

# 生成 Prisma Client 并编译 TypeScript（包含 seed.ts）
RUN npx prisma generate
RUN npm run build

# ========== 运行阶段 ==========
FROM --platform=linux/amd64 node:20-slim AS runner

WORKDIR /app

ENV NODE_ENV=production

# 安装运行时依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssl \
    ca-certificates \
    wget \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# 安装运行时依赖（生产依赖 + prisma CLI）
COPY package*.json ./
RUN npm ci --omit=dev && npm install prisma@5.22.0 @prisma/client@5.22.0

# 从构建阶段复制编译产物（包含 dist/src 和 dist/prisma）
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/public ./public
COPY --from=builder /app/public ./dist/public
COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma

# 复制启动脚本
COPY docker-entrypoint.sh ./
RUN chmod +x docker-entrypoint.sh

# 创建数据目录和上传目录（挂载点）
# 数据库通过 docker-compose 的 bind mount 挂载到 ./data:/app/data
# 上传文件挂载到 ./uploads:/app/uploads
RUN mkdir -p uploads/audio uploads/recordings uploads/voices uploads/avatars uploads/covers uploads/subtitles data

EXPOSE 9999

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:9999/health || exit 1

# 使用启动脚本
CMD ["./docker-entrypoint.sh"]
