import { Response, NextFunction } from 'express';
import bcrypt from 'bcryptjs';
import { prisma } from '../utils/prisma';
import { success, fail } from '../utils/response';
import { signToken } from '../utils/jwt';
import { AuthRequest } from '../middlewares/auth';

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
