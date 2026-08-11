import { Router } from 'express';
import { authRequired, adminRequired } from '../middlewares/auth';
import { uploadImage } from '../middlewares/upload';
import { serveFile, uploadAvatar, uploadCover, listFiles } from '../controllers/fileController';

const router = Router();

// 上传头像（登录用户）
router.post('/avatar', authRequired, uploadImage.single('avatar'), uploadAvatar);
// 上传封面（管理员）
router.post('/cover', authRequired, adminRequired, uploadImage.single('cover'), uploadCover);
// 列出文件（管理员）
router.get('/list/:type', authRequired, adminRequired, listFiles);

// 静态文件服务（公开）- 必须放在最后，因为 /:type/:filename 是通配路由
router.get('/:type/:filename', serveFile);

export default router;
