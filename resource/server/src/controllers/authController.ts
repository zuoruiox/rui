import { Response, NextFunction } from 'express';
import bcrypt from 'bcryptjs';
import { prisma } from '../utils/prisma';
import { success, fail } from '../utils/response';
import { signToken } from '../utils/jwt';
import { AuthRequest } from '../middlewares/auth';
import { logger } from '../utils/logger';

// 内存存储验证码（生产环境应使用 Redis）
const verificationCodes = new Map<string, { code: string; expiresAt: number }>();

// 生成6位数字验证码
function generateCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

function excludePassword(user: any) {
  if (!user) return user;
  const { password, ...rest } = user;
  return rest;
}

// ==================== 注册（仅普通用户） ====================
export const register = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { email, password, nickname, phone } = req.body;

    if (!nickname) {
      return fail(res, '昵称不能为空', 400);
    }
    if (!email && !phone) {
      return fail(res, '邮箱或手机号至少填写一个', 400);
    }
    if (!password) {
      return fail(res, '密码不能为空', 400);
    }
    if (password.length < 6) {
      return fail(res, '密码长度不能少于6位', 400);
    }

    // 检查邮箱是否已注册
    if (email) {
      const existingEmail = await prisma.user.findUnique({ where: { email } });
      if (existingEmail) {
        return fail(res, '该邮箱已注册', 400);
      }
    }

    // 检查手机号是否已注册
    if (phone) {
      const existingPhone = await prisma.user.findUnique({ where: { phone } });
      if (existingPhone) {
        return fail(res, '该手机号已注册', 400);
      }
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    // 注册接口只能创建普通用户，强制 role=user, status=active
    const user = await prisma.user.create({
      data: {
        email: email || null,
        phone: phone || null,
        password: hashedPassword,
        nickname,
        role: 'user',
        status: 'active',
        membershipTier: 'free',
      },
    });

    const token = signToken({ userId: user.id, role: user.role });

    return success(res, { token, user: excludePassword(user) }, '注册成功');
  } catch (err) {
    next(err);
  }
};

// ==================== 登录 ====================
export const login = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return fail(res, '邮箱和密码不能为空', 400);
    }

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user || !user.password) {
      return fail(res, '邮箱或密码错误', 401);
    }

    // 检查账号状态（active 以外的状态均禁止登录）
    if (user.status !== 'active') {
      return fail(res, '该账号已被禁用，请联系管理员', 403);
    }

    const valid = await bcrypt.compare(password, user.password);
    if (!valid) {
      return fail(res, '邮箱或密码错误', 401);
    }

    // 更新最后登录时间
    await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    const token = signToken({ userId: user.id, role: user.role });

    return success(res, { token, user: excludePassword({ ...user, lastLoginAt: new Date() }) }, '登录成功');
  } catch (err) {
    next(err);
  }
};

// ==================== 获取当前用户信息 ====================
export const me = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const userId = req.userId;
    if (!userId) {
      return fail(res, '未登录', 401);
    }

    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: { children: true },
    });

    if (!user) {
      return fail(res, '用户不存在', 404);
    }

    if (user.status !== 'active') {
      return fail(res, '该账号已被禁用', 403);
    }

    return success(res, excludePassword(user));
  } catch (err) {
    next(err);
  }
};

// ==================== 修改密码 ====================
export const changePassword = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const userId = req.userId;
    if (!userId) {
      return fail(res, '未登录', 401);
    }

    const { oldPassword, newPassword } = req.body;
    if (!oldPassword || !newPassword) {
      return fail(res, '旧密码和新密码不能为空', 400);
    }
    if (newPassword.length < 6) {
      return fail(res, '新密码长度不能少于6位', 400);
    }

    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user || !user.password) {
      return fail(res, '用户不存在', 404);
    }

    const valid = await bcrypt.compare(oldPassword, user.password);
    if (!valid) {
      return fail(res, '旧密码错误', 400);
    }

    const hashedPassword = await bcrypt.hash(newPassword, 10);
    await prisma.user.update({
      where: { id: userId },
      data: { password: hashedPassword },
    });

    return success(res, null, '密码修改成功');
  } catch (err) {
    next(err);
  }
};

// ==================== 更新个人资料 ====================
export const updateProfile = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const userId = req.userId;
    if (!userId) {
      return fail(res, '未登录', 401);
    }

    const { nickname, avatar } = req.body;
    const data: any = {};
    if (nickname !== undefined) data.nickname = nickname;
    if (avatar !== undefined) data.avatar = avatar;

    const user = await prisma.user.update({
      where: { id: userId },
      data,
      include: { children: true },
    });

    return success(res, excludePassword(user), '资料更新成功');
  } catch (err) {
    next(err);
  }
};

// ==================== 设备自动登录 ====================
export const deviceLogin = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { deviceId } = req.body;
    if (!deviceId) {
      return fail(res, '设备ID不能为空', 400);
    }

    // 使用特殊 email 标识设备用户
    const deviceEmail = `device_${deviceId}@local`;
    let user = await prisma.user.findUnique({ where: { email: deviceEmail } });

    if (!user) {
      user = await prisma.user.create({
        data: {
          email: deviceEmail,
          nickname: '宝贝家长',
          role: 'user',
          status: 'active',
          membershipTier: 'free',
        },
      });
    }

    if (user.status !== 'active') {
      return fail(res, '该设备已被禁用', 403);
    }

    const token = signToken({ userId: user.id, role: user.role });
    return success(res, { token, user: excludePassword(user) }, '登录成功');
  } catch (err) {
    next(err);
  }
};

// ==================== 发送手机验证码 ====================
export const sendCode = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { phone } = req.body;
    if (!phone || !/^1[3-9]\d{9}$/.test(phone)) {
      return fail(res, '请输入正确的手机号', 400);
    }

    const code = generateCode();
    const expiresAt = Date.now() + 5 * 60 * 1000; // 5分钟有效
    verificationCodes.set(phone, { code, expiresAt });

    // TODO: 接入真实短信服务（阿里云/腾讯云短信），目前直接返回验证码方便开发测试
    logger.info(`📱 验证码发送: ${phone} -> ${code}`);

    return success(res, { devCode: code }, '验证码已发送');
  } catch (err) {
    next(err);
  }
};

// ==================== 手机号验证码登录/注册 ====================
export const phoneLogin = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { phone, code, nickname } = req.body;
    if (!phone || !code) {
      return fail(res, '手机号和验证码不能为空', 400);
    }

    // 验证验证码
    const stored = verificationCodes.get(phone);
    if (!stored) {
      return fail(res, '请先获取验证码', 400);
    }
    if (Date.now() > stored.expiresAt) {
      verificationCodes.delete(phone);
      return fail(res, '验证码已过期，请重新获取', 400);
    }
    if (stored.code !== code) {
      return fail(res, '验证码错误', 400);
    }

    // 验证码使用后删除
    verificationCodes.delete(phone);

    // 查找或创建用户
    let user = await prisma.user.findUnique({ where: { phone } });
    if (!user) {
      // 新用户自动注册（仅普通用户）
      user = await prisma.user.create({
        data: {
          phone,
          nickname: nickname || `用户${phone.slice(-4)}`,
          role: 'user',
          status: 'active',
          membershipTier: 'free',
        },
      });
    }

    if (user.status !== 'active') {
      return fail(res, '该账号已被禁用', 403);
    }

    // 更新最后登录时间
    await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    const token = signToken({ userId: user.id, role: user.role });
    return success(res, { token, user: excludePassword({ ...user, lastLoginAt: new Date() }) }, user.createdAt.getTime() === user.updatedAt.getTime() ? '注册成功' : '登录成功');
  } catch (err) {
    next(err);
  }
};

// ==================== 微信登录/注册 ====================
export const wechatLogin = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { code, nickname: wxNickname, avatar: wxAvatar } = req.body;
    if (!code) {
      return fail(res, '微信授权code不能为空', 400);
    }

    // TODO: 接入微信开放平台，用 code 换取 openid 和 access_token
    // 目前使用 code 作为模拟 openid 方便开发测试
    const openId = code.startsWith('wx_') ? code : `wx_${code}`;
    const wechatEmail = `${openId}@wechat.local`;

    // 用 email 字段查找微信用户（不会与真实邮箱冲突）
    let user = await prisma.user.findUnique({ where: { email: wechatEmail } });

    if (!user) {
      user = await prisma.user.create({
        data: {
          email: wechatEmail,
          nickname: wxNickname || '微信用户',
          avatar: wxAvatar,
          role: 'user',
          status: 'active',
          membershipTier: 'free',
        },
      });
    } else if (wxNickname || wxAvatar) {
      user = await prisma.user.update({
        where: { id: user.id },
        data: {
          ...(wxNickname ? { nickname: wxNickname } : {}),
          ...(wxAvatar ? { avatar: wxAvatar } : {}),
        },
      });
    }

    if (user.status !== 'active') {
      return fail(res, '该账号已被禁用', 403);
    }

    await prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    const token = signToken({ userId: user.id, role: user.role });
    return success(res, { token, user: excludePassword({ ...user, lastLoginAt: new Date() }) }, '登录成功');
  } catch (err) {
    next(err);
  }
};
