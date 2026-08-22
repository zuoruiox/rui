import { Response, NextFunction } from 'express';
import { prisma } from '../utils/prisma';
import { success, fail, paginated } from '../utils/response';
import { AuthRequest } from '../middlewares/auth';

function excludePassword(user: any) {
  if (!user) return user;
  const { password, ...rest } = user;
  return rest;
}

function parsePage(query: any) {
  const page = Math.max(1, parseInt(query.page as string, 10) || 1);
  const pageSize = Math.min(100, Math.max(1, parseInt(query.pageSize as string, 10) || 20));
  return { page, pageSize };
}

// ========== 管理员：用户管理 ==========

// 获取用户列表（管理员）
export const listUsers = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { page, pageSize } = parsePage(req.query);
    const keyword = (req.query.keyword as string)?.trim();
    const role = (req.query.role as string)?.trim();
    const status = (req.query.status as string)?.trim();

    const where: any = {};
    if (role) where.role = role;
    if (status) where.status = status;
    if (keyword) {
      where.OR = [
        { email: { contains: keyword } },
        { nickname: { contains: keyword } },
        { phone: { contains: keyword } },
      ];
    }

    const [total, users] = await Promise.all([
      prisma.user.count({ where }),
      prisma.user.findMany({
        where,
        skip: (page - 1) * pageSize,
        take: pageSize,
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          email: true,
          phone: true,
          nickname: true,
          avatar: true,
          role: true,
          status: true,
          membershipTier: true,
          membershipExpireAt: true,
          lastLoginAt: true,
          createdAt: true,
          updatedAt: true,
          _count: {
            select: { children: true, voiceModels: true, aiStories: true, favorites: true },
          },
        },
      }),
    ]);

    return paginated(res, users, total, page, pageSize);
  } catch (err) {
    next(err);
  }
};

// 获取单个用户详情（管理员）
export const getUser = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const user = await prisma.user.findUnique({
      where: { id },
      include: {
        children: true,
        _count: {
          select: {
            voiceModels: true,
            favorites: true,
            aiStories: true,
            playlists: true,
          },
        },
      },
    });

    if (!user) {
      return fail(res, '用户不存在', 404);
    }

    return success(res, excludePassword(user));
  } catch (err) {
    next(err);
  }
};

// 更新用户信息（管理员：可改角色、会员、状态）
export const updateUser = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const { role, membershipTier, membershipExpireAt, nickname, avatar, status } = req.body;

    const existing = await prisma.user.findUnique({ where: { id } });
    if (!existing) {
      return fail(res, '用户不存在', 404);
    }

    // 防止管理员把自己降级或禁用
    if (id === req.userId) {
      if (role && role !== 'admin') {
        return fail(res, '不能修改自己的管理员角色', 400);
      }
      if (status && status !== 'active') {
        return fail(res, '不能禁用自己的账号', 400);
      }
    }

    const data: any = {};
    if (role !== undefined) data.role = role;
    if (status !== undefined) data.status = status;
    if (membershipTier !== undefined) data.membershipTier = membershipTier;
    if (nickname !== undefined) data.nickname = nickname;
    if (avatar !== undefined) data.avatar = avatar;
    if (membershipExpireAt !== undefined) {
      data.membershipExpireAt = membershipExpireAt ? new Date(membershipExpireAt) : null;
    }

    const user = await prisma.user.update({
      where: { id },
      data,
    });

    return success(res, excludePassword(user), '用户更新成功');
  } catch (err) {
    next(err);
  }
};

// 删除用户（管理员）
export const deleteUser = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;

    const existing = await prisma.user.findUnique({ where: { id } });
    if (!existing) {
      return fail(res, '用户不存在', 404);
    }

    // 防止管理员删除自己
    if (id === req.userId) {
      return fail(res, '不能删除自己的账号', 400);
    }

    await prisma.user.delete({ where: { id } });
    return success(res, null, '用户删除成功');
  } catch (err) {
    next(err);
  }
};

// ========== 孩子档案（当前登录用户） ==========

// 获取我的孩子档案列表
export const listChildren = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const userId = req.userId;
    if (!userId) {
      return fail(res, '未登录', 401);
    }

    const children = await prisma.child.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });

    return success(res, children);
  } catch (err) {
    next(err);
  }
};

export const addChild = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const userId = req.userId;
    if (!userId) {
      return fail(res, '未登录', 401);
    }

    const { name, gender, birthday, ageGroup, age, interests, avatar } = req.body;
    if (!name) {
      return fail(res, '孩子姓名不能为空', 400);
    }

    // 兼容前端传 age 数字，转换为 ageGroup
    let resolvedAgeGroup = ageGroup;
    if (age !== undefined && age !== null && !ageGroup) {
      const ageNum = parseInt(age);
      if (!isNaN(ageNum)) {
        if (ageNum <= 3) resolvedAgeGroup = '0-3';
        else if (ageNum <= 6) resolvedAgeGroup = '3-6';
        else if (ageNum <= 9) resolvedAgeGroup = '6-9';
        else resolvedAgeGroup = '9-12';
      }
    }

    const child = await prisma.child.create({
      data: {
        userId,
        name,
        gender: gender || null,
        birthday: birthday ? new Date(birthday) : null,
        ageGroup: resolvedAgeGroup || null,
        interests: interests || null,
        avatar: avatar || null,
      },
    });

    return success(res, child, '添加成功');
  } catch (err) {
    next(err);
  }
};

export const updateChild = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const userId = req.userId;
    const { childId } = req.params;
    if (!userId) {
      return fail(res, '未登录', 401);
    }

    const existing = await prisma.child.findUnique({ where: { id: childId } });
    if (!existing || existing.userId !== userId) {
      return fail(res, '孩子档案不存在', 404);
    }

    const { name, gender, birthday, ageGroup, age, interests, avatar } = req.body;
    const data: any = {};
    if (name !== undefined) data.name = name;
    if (gender !== undefined) data.gender = gender;
    if (ageGroup !== undefined) data.ageGroup = ageGroup;
    if (age !== undefined && age !== null) {
      const ageNum = parseInt(age);
      if (!isNaN(ageNum)) {
        if (ageNum <= 3) data.ageGroup = '0-3';
        else if (ageNum <= 6) data.ageGroup = '3-6';
        else if (ageNum <= 9) data.ageGroup = '6-9';
        else data.ageGroup = '9-12';
      }
    }
    if (interests !== undefined) data.interests = interests;
    if (avatar !== undefined) data.avatar = avatar;
    if (birthday !== undefined) {
      data.birthday = birthday ? new Date(birthday) : null;
    }

    const child = await prisma.child.update({
      where: { id: childId },
      data,
    });

    return success(res, child, '更新成功');
  } catch (err) {
    next(err);
  }
};

export const deleteChild = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const userId = req.userId;
    const { childId } = req.params;
    if (!userId) {
      return fail(res, '未登录', 401);
    }

    const existing = await prisma.child.findUnique({ where: { id: childId } });
    if (!existing || existing.userId !== userId) {
      return fail(res, '孩子档案不存在', 404);
    }

    await prisma.child.delete({ where: { id: childId } });
    return success(res, null, '删除成功');
  } catch (err) {
    next(err);
  }
};

// ========== 系统统计（管理员） ==========

export const getStats = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const startOfYesterday = new Date(startOfToday.getTime() - 24 * 60 * 60 * 1000);

    const [
      totalUsers,
      totalStories,
      totalVoiceModels,
      todayNewUsers,
      yesterdayNewUsers,
      totalAIStories,
      totalFavorites,
      activeUsers,
    ] = await Promise.all([
      prisma.user.count(),
      prisma.story.count(),
      prisma.voiceModel.count(),
      prisma.user.count({ where: { createdAt: { gte: startOfToday } } }),
      prisma.user.count({ where: { createdAt: { gte: startOfYesterday, lt: startOfToday } } }),
      prisma.aIStory.count(),
      prisma.favorite.count(),
      prisma.user.count({ where: { lastLoginAt: { gte: startOfToday } } }),
    ]);

    return success(res, {
      totalUsers,
      totalStories,
      totalVoiceModels,
      totalAIStories,
      totalFavorites,
      todayNewUsers,
      yesterdayNewUsers,
      todayActiveUsers: activeUsers,
    });
  } catch (err) {
    next(err);
  }
};
