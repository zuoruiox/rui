import { Router } from 'express';
import {
  listUsers,
  getUser,
  updateUser,
  deleteUser,
  listChildren,
  addChild,
  updateChild,
  deleteChild,
  getStats,
} from '../controllers/userController';
import { authRequired, adminRequired } from '../middlewares/auth';

const router = Router();

// 孩子档案（当前登录用户）- 必须放在 /:id 之前，避免 "children" 被当作 id 匹配
router.get('/children', authRequired, listChildren);
router.post('/children', authRequired, addChild);
router.put('/children/:childId', authRequired, updateChild);
router.delete('/children/:childId', authRequired, deleteChild);

// 管理员路由
router.get('/', authRequired, adminRequired, listUsers);
router.get('/stats', authRequired, adminRequired, getStats);
router.get('/:id', authRequired, adminRequired, getUser);
router.put('/:id', authRequired, adminRequired, updateUser);
router.delete('/:id', authRequired, adminRequired, deleteUser);

export default router;
