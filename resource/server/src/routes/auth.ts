import { Router } from 'express';
import {
  register,
  login,
  me,
  changePassword,
  updateProfile,
  sendCode,
  phoneLogin,
  wechatLogin,
} from '../controllers/authController';
import { authRequired } from '../middlewares/auth';

const router = Router();

router.post('/register', register);
router.post('/login', login);
router.post('/send-code', sendCode);
router.post('/phone-login', phoneLogin);
router.post('/wechat-login', wechatLogin);
router.get('/me', authRequired, me);
router.post('/change-password', authRequired, changePassword);
router.put('/profile', authRequired, updateProfile);

export default router;
