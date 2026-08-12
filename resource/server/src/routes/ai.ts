import { Router } from 'express';
import { authRequired } from '../middlewares/auth';
import { generateStory, myStories } from '../controllers/aiController';

const router = Router();

// AI生成故事
router.post('/generate', authRequired, generateStory);

// 我的AI故事列表
router.get('/my-stories', authRequired, myStories);

export default router;