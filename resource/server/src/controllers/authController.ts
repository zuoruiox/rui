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

export const register = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { email, password, nickname } = req.body;

    if (!email || !password || !nickname) {
      return fail(res, '邮箱、密码和昵称不能为空', 400);
    }

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      return fail(res, '该邮箱已注册', 400);
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const user = await prisma.user.create({
      data: {
        email,
        password: hashedPassword,
        nickname,
      },
    });

    const token = signToken({ userId: user.id, role: user.role });

    return success(res, { token, user: excludePassword(user) }, '注册成功');
  } catch (err) {
    next(err);
  }
};

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

    const valid = await bcrypt.compare(password, user.password);
    if (!valid) {
      return fail(res, '邮箱或密码错误', 401);
    }

    const token = signToken({ userId: user.id, role: user.role });

    return success(res, { token, user: excludePassword(user) }, '登录成功');
  } catch (err) {
    next(err);
  }
};

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

    return success(res, excludePassword(user));
  } catch (err) {
    next(err);
  }
};

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

// 设备自动登录 - 用设备ID创建或获取匿名用户
export const deviceLogin = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { deviceId } = req.body;
    if (!deviceId) {
      return fail(res, '设备ID不能为空', 400);
    }

    // 查找是否已有该设备的用户（通过 email 匹配 deviceId@device.local）
    const deviceEmail = `device_${deviceId}@device.local`;
    let user = await prisma.user.findUnique({ where: { email: deviceEmail } });

    if (!user) {
      // 自动创建匿名用户
      user = await prisma.user.create({
        data: {
          email: deviceEmail,
          nickname: '宝贝家长',
          role: 'user',
          membershipTier: 'free',
        },
      });
    }

    const token = signToken({ userId: user.id, role: user.role });
    return success(res, { token, user: excludePassword(user) }, '登录成功');
  } catch (err) {
    next(err);
  }
};

// 发送手机验证码
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

// 手机号验证码登录/注册（一键注册）
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
      // 新用户自动注册
      user = await prisma.user.create({
        data: {
          phone,
          nickname: nickname || `用户${phone.slice(-4)}`,
          role: 'user',
          membershipTier: 'free',
        },
      });
    }

    const token = signToken({ userId: user.id, role: user.role });
    return success(res, { token, user: excludePassword(user) }, user.createdAt === user.updatedAt ? '注册成功' : '登录成功');
  } catch (err) {
    next(err);
  }
};

// 微信登录/注册
export const wechatLogin = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { code, nickname: wxNickname, avatar: wxAvatar } = req.body;
    if (!code) {
      return fail(res, '微信授权code不能为空', 400);
    }

    // TODO: 接入微信开放平台，用 code 换取 openid 和 access_token
    // 目前使用 code 作为模拟 openid 方便开发测试
    const mockOpenId = `wx_${code}`;

    // 用 openid 查找或创建用户（通过 email 字段存储 wx_openid 标识）
    const wechatEmail = `${mockOpenId}@wechat.local`;
    let user = await prisma.user.findUnique({ where: { email: wechatEmail } });

    if (!user) {
      user = await prisma.user.create({
        data: {
          email: wechatEmail,
          nickname: wxNickname || '微信用户',
          avatar: wxAvatar,
          role: 'user',
          membershipTier: 'free',
        },
      });
    } else if (wxNickname || wxAvatar) {
      // 更新微信头像和昵称
      user = await prisma.user.update({
        where: { id: user.id },
        data: {
          ...(wxNickname ? { nickname: wxNickname } : {}),
          ...(wxAvatar ? { avatar: wxAvatar } : {}),
        },
      });
    }

    const token = signToken({ userId: user.id, role: user.role });
    return success(res, { token, user: excludePassword(user) }, '登录成功');
  } catch (err) {
    next(err);
  }
};
