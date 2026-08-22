import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import path from 'path';
import dotenv from 'dotenv';
import { errorHandler } from './middlewares/errorHandler';
import { logger } from './utils/logger';

// 路由
import authRoutes from './routes/auth';
import userRoutes from './routes/users';
import storyRoutes from './routes/stories';
import voiceRoutes from './routes/voices';
import fileRoutes from './routes/files';
import aiRoutes from './routes/ai';

dotenv.config();

const app = express();
const PORT = parseInt(process.env.PORT || '3000', 10);

// 中间件
app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' },
  contentSecurityPolicy: false, // 管理后台需要内联脚本，禁用 CSP
}));
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(morgan('dev'));

// 静态文件 - 前端（管理后台 + 用户端）
app.use(express.static(path.join(__dirname, '../public')));
app.get('/admin', (req, res) => {
  res.sendFile(path.join(__dirname, '../public/index.html'));
});

// API 路由
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/stories', storyRoutes);
app.use('/api/voices', voiceRoutes);
app.use('/api/files', fileRoutes);
app.use('/api/ai', aiRoutes);

// 根路径重定向到管理后台
app.get('/', (req, res) => {
  res.redirect('/admin');
});

// API 404
app.use('/api', (req, res) => {
  res.status(404).json({ code: 404, message: '接口不存在', data: null });
});

// 全局错误处理
app.use(errorHandler);

app.listen(PORT, () => {
  logger.info(`🚀 爸爸妈妈讲故事服务器启动成功！`);
  logger.info(`📡 服务地址: http://localhost:${PORT}`);
  logger.info(`🎛️  管理后台: http://localhost:${PORT}/admin`);
  logger.info(`📊 API 文档: http://localhost:${PORT}/api`);
});

export default app;
