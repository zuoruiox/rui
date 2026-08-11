# 爸爸妈妈讲故事 - 服务端

为"爸爸妈妈讲故事"iOS App 提供后端服务的 Node.js 项目，包含资源服务、用户管理、声音克隆管理、API 接口和管理后台。

## 技术栈

- **运行时**: Node.js 20+
- **框架**: Express + TypeScript
- **数据库**: SQLite（开发）/ PostgreSQL（生产，需修改 schema）
- **ORM**: Prisma
- **认证**: JWT
- **文件存储**: 本地文件系统
- **管理后台**: 原生 HTML/CSS/JS 单页应用

## 快速开始

### 方式一：本地开发

```bash
# 1. 安装依赖
cd server
npm install

# 2. 初始化数据库
npm run db:generate
npm run db:push
npm run db:seed

# 3. 启动开发服务器
npm run dev
```

服务启动后访问：
- 管理后台: http://localhost:3000/admin
- API 地址: http://localhost:3000/api

### 方式二：Docker 部署

```bash
# 构建并启动
docker-compose up -d

# 查看日志
docker-compose logs -f
```

## 默认账号

| 角色 | 邮箱 | 密码 |
|------|------|------|
| 管理员 | admin@mamababa.com | admin123456 |
| 测试用户 | test@mamababa.com | test123456 |

## 项目结构

```
server/
├── prisma/
│   ├── schema.prisma      # 数据库模型定义
│   └── seed.ts            # 种子数据
├── public/
│   └── index.html         # 管理后台前端
├── src/
│   ├── controllers/       # 控制器
│   │   ├── authController.ts
│   │   ├── userController.ts
│   │   ├── storyController.ts
│   │   ├── voiceController.ts
│   │   └── fileController.ts
│   ├── middlewares/       # 中间件
│   │   ├── auth.ts        # JWT 认证
│   │   ├── upload.ts      # 文件上传
│   │   └── errorHandler.ts
│   ├── routes/            # 路由
│   │   ├── auth.ts
│   │   ├── users.ts
│   │   ├── stories.ts
│   │   ├── voices.ts
│   │   └── files.ts
│   ├── utils/             # 工具函数
│   │   ├── prisma.ts
│   │   ├── jwt.ts
│   │   ├── response.ts
│   │   └── logger.ts
│   ├── types/
│   │   └── index.ts
│   └── index.ts           # 入口文件
├── uploads/               # 文件上传目录
│   ├── audio/             # 故事音频
│   ├── recordings/        # 用户录音
│   ├── voices/            # 声音模型文件
│   ├── avatars/           # 用户头像
│   └── covers/            # 封面图片
├── Dockerfile
├── docker-compose.yml
├── package.json
└── tsconfig.json
```

## API 接口

### 认证接口
| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| POST | /api/auth/register | 用户注册 | 否 |
| POST | /api/auth/login | 用户登录 | 否 |
| GET | /api/auth/me | 获取当前用户 | 是 |
| POST | /api/auth/change-password | 修改密码 | 是 |
| PUT | /api/auth/profile | 更新资料 | 是 |

### 用户管理
| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| GET | /api/users | 用户列表（分页） | 管理员 |
| GET | /api/users/stats | 系统统计 | 管理员 |
| GET | /api/users/:id | 用户详情 | 管理员 |
| PUT | /api/users/:id | 更新用户 | 管理员 |
| DELETE | /api/users/:id | 删除用户 | 管理员 |
| POST | /api/users/children | 添加孩子档案 | 是 |
| PUT | /api/users/children/:id | 更新孩子档案 | 是 |
| DELETE | /api/users/children/:id | 删除孩子档案 | 是 |

### 故事管理
| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| GET | /api/stories | 故事列表（分页+筛选） | 可选 |
| GET | /api/stories/categories | 分类列表 | 可选 |
| GET | /api/stories/:id | 故事详情 | 可选 |
| POST | /api/stories | 创建故事 | 管理员 |
| PUT | /api/stories/:id | 更新故事 | 管理员 |
| DELETE | /api/stories/:id | 删除故事 | 管理员 |
| POST | /api/stories/:id/audio | 上传故事音频 | 管理员 |
| POST | /api/stories/categories | 创建分类 | 管理员 |
| PUT | /api/stories/categories/:id | 更新分类 | 管理员 |
| DELETE | /api/stories/categories/:id | 删除分类 | 管理员 |
| GET | /api/stories/favorites | 我的收藏 | 是 |
| POST | /api/stories/favorites | 切换收藏 | 是 |
| GET | /api/stories/history | 播放历史 | 是 |
| GET/POST/PUT/DELETE | /api/stories/playlists | 播放列表管理 | 是 |

### 声音克隆
| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| GET | /api/voices | 我的声音模型 | 是 |
| POST | /api/voices | 创建声音模型 | 是 |
| GET | /api/voices/all | 所有声音模型 | 管理员 |
| GET | /api/voices/:id | 模型详情 | 是 |
| POST | /api/voices/:id/recordings | 上传录音 | 是 |
| DELETE | /api/voices/recordings/:id | 删除录音 | 是 |
| POST | /api/voices/:id/train | 开始训练 | 是 |
| DELETE | /api/voices/:id | 删除模型 | 是 |
| POST | /api/voices/synthesize | 合成语音 | 是 |

### 文件服务
| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| GET | /api/files/:type/:filename | 访问文件 | 公开 |
| POST | /api/files/avatar | 上传头像 | 是 |
| POST | /api/files/cover | 上传封面 | 管理员 |

## 数据库模型

- **User**: 用户（含角色、会员等级）
- **Child**: 孩子档案
- **Story**: 故事（含分类、标签、音频）
- **StoryCategory**: 故事分类
- **Favorite**: 收藏
- **PlayHistory**: 播放历史
- **Playlist**: 播放列表
- **Download**: 下载记录
- **VoiceModel**: 声音克隆模型
- **RecordingSample**: 录音样本
- **AIStory**: AI 生成的故事
- **SystemConfig**: 系统配置

## 环境变量

在 `.env` 文件中配置：

```env
# 数据库
DATABASE_URL="file:./dev.db"

# JWT
JWT_SECRET="your-secret-key"
JWT_EXPIRES_IN="7d"

# 服务
PORT=3000
NODE_ENV="development"

# 文件上传
UPLOAD_DIR="./uploads"

# 管理员账号（首次启动时创建）
ADMIN_EMAIL="admin@mamababa.com"
ADMIN_PASSWORD="admin123456"
```

## 切换到 PostgreSQL

1. 修改 `prisma/schema.prisma` 中的 datasource：
```prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}
```

2. 修改 `.env` 中的 `DATABASE_URL`：
```
DATABASE_URL="postgresql://user:password@localhost:5432/mamababa?schema=public"
```

3. 重新生成和推送：
```bash
npx prisma generate
npx prisma db push
```

## 常用命令

```bash
npm run dev          # 开发模式（热重载）
npm run build        # 构建
npm start            # 生产模式启动
npm run db:generate  # 生成 Prisma Client
npm run db:push      # 推送数据库 schema
npm run db:seed      # 运行种子数据
```

## iOS App 对接

iOS App 的 API Client 中 baseURL 设置为服务器地址即可。所有需要认证的接口在请求头中添加：

```
Authorization: Bearer <token>
```

登录/注册成功后保存返回的 token，后续请求自动携带。
