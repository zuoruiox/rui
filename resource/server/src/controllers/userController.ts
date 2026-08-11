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

export const listUsers = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { page, pageSize } = parsePage(req.query);
    const keyword = (req.query.keyword as string)?.trim();
    const role = (req.query.role as string)?.trim();

    const where: any = {};
    if (role) where.role = role;
    if (keyword) {
      where.OR = [
        { email: { contains: keyword } },
        { nickname: { contains: keyword } },
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
          membershipTier: true,
          membershipExpireAt: true,
          createdAt: true,
          updatedAt: true,
          _count: {
            select: { children: true, voiceModels: true },
          },
        },
      }),
    ]);

    return paginated(res, users, total, page, pageSize);
  } catch (err) {
    next(err);
  }
};

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

export const updateUser = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const { role, membershipTier, membershipExpireAt, nickname, avatar } = req.body;

    const existing = await prisma.user.findUnique({ where: { id } });
    if (!existing) {
      return fail(res, '用户不存在', 404);
    }

    const data: any = {};
    if (role !== undefined) data.role = role;
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

export const deleteUser = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;

    const existing = await prisma.user.findUnique({ where: { id } });
    if (!existing) {
      return fail(res, '用户不存在', 404);
    }

    await prisma.user.delete({ where: { id } });
    return success(res, null, '用户删除成功');
  } catch (err) {
    next(err);
  }
};

// ========== 孩子档案（当前用户） ==========

export const addChild = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const userId = req.userId;
    if (!userId) {
      return fail(res, '未登录', 401);
    }

    const { name, gender, birthday, ageGroup, interests, avatar } = req.body;
    if (!name) {
      return fail(res, '孩子姓名不能为空', 400);
    }

    const child = await prisma.child.create({
      data: {
        userId,
        name,
        gender: gender || null,
        birthday: birthday ? new Date(birthday) : null,
        ageGroup: ageGroup || null,
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

    const { name, gender, birthday, ageGroup, interests, avatar } = req.body;
    const data: any = {};
    if (name !== undefined) data.name = name;
    if (gender !== undefined) data.gender = gender;
    if (ageGroup !== undefined) data.ageGroup = ageGroup;
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

// ========== 系统统计 ==========

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
    ] = await Promise.all([
      prisma.user.count(),
      prisma.story.count(),
      prisma.voiceModel.count(),
      prisma.user.count({ where: { createdAt: { gte: startOfToday } } }),
      prisma.user.count({ where: { createdAt: { gte: startOfYesterday, lt: startOfToday } } }),
      prisma.aIStory.count(),
      prisma.favorite.count(),
    ]);

    return success(res, {
      totalUsers,
      totalStories,
      totalVoiceModels,
      totalAIStories,
      totalFavorites,
      todayNewUsers,
      yesterdayNewUsers,
    });
  } catch (err) {
    next(err);
  }
};
