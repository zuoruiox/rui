import { Response, NextFunction } from 'express';
import bcrypt from 'bcryptjs';
import fetch from 'node-fetch';
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

    let openId: string;
    let unionId: string | undefined;

    // 开发模式：code 以 wx_mock_ 开头时直接使用模拟 openId
    if (code.startsWith('wx_mock_')) {
      openId = code;
      logger.info(`[微信登录] 开发模式，使用模拟 openId: ${openId}`);
    } else {
      // 生产模式：通过 code 调用微信 API 换取 openid 和 session_key
      const appId = process.env.WECHAT_APP_ID;
      const appSecret = process.env.WECHAT_APP_SECRET;

      if (!appId || !appSecret) {
        logger.error('[微信登录] WECHAT_APP_ID 或 WECHAT_APP_SECRET 未配置');
        return fail(res, '微信登录未配置，请联系管理员', 500);
      }

      const url = `https://api.weixin.qq.com/sns/oauth2/access_token?appid=${appId}&secret=${appSecret}&code=${code}&grant_type=authorization_code`;

      const wxResp = await fetch(url);
      const wxData = await wxResp.json() as any;

      if (wxData.errcode) {
        logger.error(`[微信登录] 微信API错误: ${JSON.stringify(wxData)}`);
        return fail(res, `微信授权失败: ${wxData.errmsg || '未知错误'}`, 400);
      }

      openId = wxData.openid;
      unionId = wxData.unionid;

      if (!openId) {
        return fail(res, '获取微信用户信息失败', 400);
      }

      logger.info(`[微信登录] 微信授权成功，openId: ${openId}, unionId: ${unionId || '无'}`);
    }

    // 通过 wechatOpenId 查找微信用户
    let user = await prisma.user.findFirst({ where: { wechatOpenId: openId } });

    if (!user) {
      // 新用户自动注册
      user = await prisma.user.create({
        data: {
          wechatOpenId: openId,
          wechatUnionId: unionId,
          nickname: wxNickname || '微信用户',
          avatar: wxAvatar,
          role: 'user',
          status: 'active',
          membershipTier: 'free',
        },
      });
      logger.info(`[微信登录] 新用户注册: ${user.id}, nickname: ${user.nickname}`);
    } else {
      // 已有用户，更新资料（如果有新的昵称/头像/unionId）
      const updateData: any = {};
      if (wxNickname && user.nickname !== wxNickname) updateData.nickname = wxNickname;
      if (wxAvatar && user.avatar !== wxAvatar) updateData.avatar = wxAvatar;
      if (unionId && !user.wechatUnionId) updateData.wechatUnionId = unionId;

      if (Object.keys(updateData).length > 0) {
        user = await prisma.user.update({
          where: { id: user.id },
          data: updateData,
        });
      }
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
