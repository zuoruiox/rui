import { Router } from 'express';
import {
  register,
  login,
  me,
  changePassword,
  updateProfile,
} from '../controllers/authController';
import { authRequired } from '../middlewares/auth';

const router = Router();

router.post('/register', register);
router.post('/login', login);
router.get('/me', authRequired, me);
router.post('/change-password', authRequired, changePassword);
router.put('/profile', authRequired, updateProfile);

export default router;
