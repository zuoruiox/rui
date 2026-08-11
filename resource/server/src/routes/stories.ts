import { Router } from 'express';
import { authRequired, adminRequired, optionalAuth } from '../middlewares/auth';
import { uploadAudio, uploadStoryFiles, uploadSubtitle } from '../middlewares/upload';
import {
  listStories,
  getStory,
  listCategories,
  getFavorites,
  toggleFavorite,
  getPlayHistory,
  getPlaylists,
  createPlaylist,
  updatePlaylist,
  deletePlaylist,
  createStory,
  updateStory,
  deleteStory,
  uploadStoryAudio,
  createCategory,
  updateCategory,
  deleteCategory,
  uploadStory,
  uploadSubtitle as uploadSubtitleController,
  getStorySubtitles,
  updateSubtitles,
} from '../controllers/storyController';

const router = Router();

// ==================== 公开/半公开接口 ====================

// 故事列表 - optionalAuth
router.get('/', optionalAuth, listStories);

// 分类列表 - optionalAuth
router.get('/categories', optionalAuth, listCategories);

// 故事字幕（公开访问）
router.get('/:id/subtitles', optionalAuth, getStorySubtitles);

// ==================== 需要登录的接口 ====================

// 收藏列表
router.get('/favorites', authRequired, getFavorites);

// 切换收藏
router.post('/favorites', authRequired, toggleFavorite);

// 播放历史
router.get('/history', authRequired, getPlayHistory);

// 播放列表
router.get('/playlists', authRequired, getPlaylists);
router.post('/playlists', authRequired, createPlaylist);
router.put('/playlists/:id', authRequired, updatePlaylist);
router.delete('/playlists/:id', authRequired, deletePlaylist);

// ==================== 管理员接口 ====================

// 完整上传故事（音频+字幕+封面+信息）
router.post(
  '/upload',
  authRequired,
  adminRequired,
  uploadStoryFiles.fields([
    { name: 'audio', maxCount: 1 },
    { name: 'subtitle', maxCount: 1 },
    { name: 'cover', maxCount: 1 },
  ]),
  uploadStory
);

// 创建故事（纯文本）
router.post('/', authRequired, adminRequired, createStory);

// 分类管理
router.post('/categories', authRequired, adminRequired, createCategory);
router.put('/categories/:id', authRequired, adminRequired, updateCategory);
router.delete('/categories/:id', authRequired, adminRequired, deleteCategory);

// 上传故事音频
router.post(
  '/:id/audio',
  authRequired,
  adminRequired,
  uploadAudio.single('audio'),
  uploadStoryAudio
);

// 上传/更新字幕（支持文件或文本）
router.post(
  '/:id/subtitle',
  authRequired,
  adminRequired,
  uploadSubtitle.single('subtitle'),
  uploadSubtitleController
);

// 更新字幕（手动编辑 JSON）
router.put(
  '/:id/subtitles',
  authRequired,
  adminRequired,
  updateSubtitles
);

// 故事详情（注意放在 /:id 路由之前的具体路径已定义）
router.get('/:id', optionalAuth, getStory);
router.put('/:id', authRequired, adminRequired, updateStory);
router.delete('/:id', authRequired, adminRequired, deleteStory);

export default router;
