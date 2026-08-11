import { Request, Response, NextFunction } from 'express';
import fs from 'fs';
import path from 'path';
import { prisma } from '../utils/prisma';
import { success, fail, paginated } from '../utils/response';
import { AuthRequest } from '../middlewares/auth';
import { uploadDirs } from '../middlewares/upload';
import { parseSubtitle, cuesToJSON, cuesFromJSON, SubtitleCue } from '../utils/subtitle';
import { StoryQuery, PaginationQuery } from '../types';

// ==================== 公开接口 ====================

// GET /api/stories - 故事列表
export const listStories = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const pageSize = Math.min(100, Math.max(1, parseInt(req.query.pageSize as string) || 20));
    const theme = req.query.theme as string | undefined;
    const style = req.query.style as string | undefined;
    const targetAgeGroup = req.query.targetAgeGroup as string | undefined;
    const categoryId = req.query.categoryId as string | undefined;
    const keyword = req.query.keyword as string | undefined;
    const sortBy = (req.query.sortBy as string) || 'newest';
    const isPremium = req.query.isPremium as string | undefined;
    const status = req.query.status as string | undefined;

    const where: any = {};

    // Non-admin users only see published stories; admin can filter by status
    if (req.userRole === 'admin' && status) {
      where.status = status;
    } else if (req.userRole !== 'admin') {
      where.status = 'published';
    }
    // If admin and no status filter, show all stories

    if (theme) where.theme = theme;
    if (style) where.style = style;
    if (targetAgeGroup) where.targetAgeGroup = targetAgeGroup;
    if (categoryId) where.categoryId = categoryId;
    if (isPremium !== undefined) where.isPremium = isPremium === 'true';
    if (keyword) {
      where.OR = [
        { title: { contains: keyword } },
        { summary: { contains: keyword } },
      ];
    }

    const orderBy: any =
      sortBy === 'popular'
        ? { playCount: 'desc' }
        : { createdAt: 'desc' };

    const [stories, total] = await Promise.all([
      prisma.story.findMany({
        where,
        orderBy,
        skip: (page - 1) * pageSize,
        take: pageSize,
        include: {
          category: true,
        },
      }),
      prisma.story.count({ where }),
    ]);

    // 如果用户已登录，标记是否已收藏
    let favoriteStoryIds: Set<string> = new Set();
    if (req.userId) {
      const favorites = await prisma.favorite.findMany({
        where: { userId: req.userId, storyId: { in: stories.map((s) => s.id) } },
        select: { storyId: true },
      });
      favoriteStoryIds = new Set(favorites.map((f) => f.storyId));
    }

    const storiesWithFav = stories.map((s) => ({
      ...s,
      isFavorited: favoriteStoryIds.has(s.id),
    }));

    paginated(res, storiesWithFav, total, page, pageSize);
  } catch (err) {
    next(err);
  }
};

// GET /api/stories/:id - 故事详情
export const getStory = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;

    const story = await prisma.story.findUnique({
      where: { id },
      include: { category: true },
    });

    if (!story) {
      return fail(res, '故事不存在', 404);
    }

    // 增加播放次数
    await prisma.story.update({
      where: { id },
      data: { playCount: { increment: 1 } },
    });

    let isFavorited = false;
    if (req.userId) {
      // 检查收藏
      const fav = await prisma.favorite.findUnique({
        where: { userId_storyId: { userId: req.userId, storyId: id } },
      });
      isFavorited = !!fav;

      // 记录/更新播放历史
      const existingHistory = await prisma.playHistory.findFirst({
        where: { userId: req.userId, storyId: id },
      });

      if (existingHistory) {
        await prisma.playHistory.update({
          where: { id: existingHistory.id },
          data: { updatedAt: new Date() },
        });
      } else {
        await prisma.playHistory.create({
          data: {
            userId: req.userId,
            storyId: id,
            duration: story.duration,
          },
        });
      }
    }

    success(res, { ...story, isFavorited, playCount: story.playCount + 1 });
  } catch (err) {
    next(err);
  }
};

// GET /api/stories/categories - 分类列表
export const listCategories = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const categories = await prisma.storyCategory.findMany({
      orderBy: { sortOrder: 'asc' },
      include: {
        _count: { select: { stories: true } },
      },
    });

    const result = categories.map((c) => ({
      id: c.id,
      name: c.name,
      icon: c.icon,
      description: c.description,
      sortOrder: c.sortOrder,
      storyCount: c._count.stories,
      createdAt: c.createdAt,
      updatedAt: c.updatedAt,
    }));

    success(res, result);
  } catch (err) {
    next(err);
  }
};

// GET /api/stories/favorites - 收藏列表
export const getFavorites = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const page = parseInt(req.query.page as string) || 1;
    const pageSize = parseInt(req.query.pageSize as string) || 20;

    const where = { userId: req.userId! };

    const [favorites, total] = await Promise.all([
      prisma.favorite.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * pageSize,
        take: pageSize,
        include: { story: { include: { category: true } } },
      }),
      prisma.favorite.count({ where }),
    ]);

    const stories = favorites.map((f) => ({ ...f.story, isFavorited: true }));
    paginated(res, stories, total, page, pageSize);
  } catch (err) {
    next(err);
  }
};

// POST /api/stories/favorites - 切换收藏
export const toggleFavorite = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { storyId } = req.body;
    if (!storyId) {
      return fail(res, 'storyId 不能为空', 400);
    }

    const story = await prisma.story.findUnique({ where: { id: storyId } });
    if (!story) {
      return fail(res, '故事不存在', 404);
    }

    const existing = await prisma.favorite.findUnique({
      where: { userId_storyId: { userId: req.userId!, storyId } },
    });

    if (existing) {
      await prisma.favorite.delete({ where: { id: existing.id } });
      await prisma.story.update({
        where: { id: storyId },
        data: { favoriteCount: { decrement: 1 } },
      });
      success(res, { isFavorited: false });
    } else {
      await prisma.favorite.create({
        data: { userId: req.userId!, storyId },
      });
      await prisma.story.update({
        where: { id: storyId },
        data: { favoriteCount: { increment: 1 } },
      });
      success(res, { isFavorited: true });
    }
  } catch (err) {
    next(err);
  }
};

// GET /api/stories/history - 播放历史
export const getPlayHistory = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const page = parseInt(req.query.page as string) || 1;
    const pageSize = parseInt(req.query.pageSize as string) || 20;

    const where = { userId: req.userId! };

    const [history, total] = await Promise.all([
      prisma.playHistory.findMany({
        where,
        orderBy: { updatedAt: 'desc' },
        skip: (page - 1) * pageSize,
        take: pageSize,
        include: { story: { include: { category: true } } },
      }),
      prisma.playHistory.count({ where }),
    ]);

    const items = history.map((h) => ({
      id: h.id,
      position: h.position,
      duration: h.duration,
      completed: h.completed,
      createdAt: h.createdAt,
      updatedAt: h.updatedAt,
      story: h.story,
    }));

    paginated(res, items, total, page, pageSize);
  } catch (err) {
    next(err);
  }
};

// GET /api/stories/playlists - 播放列表
export const getPlaylists = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const playlists = await prisma.playlist.findMany({
      where: { userId: req.userId! },
      orderBy: { updatedAt: 'desc' },
    });

    const result = playlists.map((p) => ({
      ...p,
      storyIds: p.storyIds ? JSON.parse(p.storyIds) : [],
    }));

    success(res, result);
  } catch (err) {
    next(err);
  }
};

// POST /api/stories/playlists - 创建播放列表
export const createPlaylist = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { name, description, coverEmoji, storyIds } = req.body;
    if (!name) {
      return fail(res, '名称不能为空', 400);
    }

    const playlist = await prisma.playlist.create({
      data: {
        userId: req.userId!,
        name,
        description: description || null,
        coverEmoji: coverEmoji || '📋',
        storyIds: storyIds ? JSON.stringify(storyIds) : '[]',
      },
    });

    return res.status(201).json({ code: 0, message: 'success', data: { ...playlist, storyIds: storyIds || [] } });
  } catch (err) {
    next(err);
  }
};

// PUT /api/stories/playlists/:id - 更新播放列表
export const updatePlaylist = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const { name, description, coverEmoji, storyIds } = req.body;

    const playlist = await prisma.playlist.findUnique({ where: { id } });
    if (!playlist) {
      return fail(res, '播放列表不存在', 404);
    }
    if (playlist.userId !== req.userId) {
      return fail(res, '无权操作', 403);
    }

    const data: any = {};
    if (name !== undefined) data.name = name;
    if (description !== undefined) data.description = description;
    if (coverEmoji !== undefined) data.coverEmoji = coverEmoji;
    if (storyIds !== undefined) data.storyIds = JSON.stringify(storyIds);

    const updated = await prisma.playlist.update({
      where: { id },
      data,
    });

    success(res, { ...updated, storyIds: JSON.parse(updated.storyIds) });
  } catch (err) {
    next(err);
  }
};

// DELETE /api/stories/playlists/:id - 删除播放列表
export const deletePlaylist = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;

    const playlist = await prisma.playlist.findUnique({ where: { id } });
    if (!playlist) {
      return fail(res, '播放列表不存在', 404);
    }
    if (playlist.userId !== req.userId) {
      return fail(res, '无权操作', 403);
    }

    await prisma.playlist.delete({ where: { id } });
    success(res, { message: '删除成功' });
  } catch (err) {
    next(err);
  }
};

// ==================== 管理员接口 ====================

// POST /api/stories - 创建故事
export const createStory = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const {
      title,
      content,
      summary,
      theme,
      style,
      targetAgeGroup,
      coverEmoji,
      coverGradient,
      audioUrl,
      duration,
      wordCount,
      tags,
      characters,
      categoryId,
      isPremium,
      status,
    } = req.body;

    if (!title || !content || !theme || !style || !targetAgeGroup) {
      return fail(res, '缺少必填字段', 400);
    }

    // Helper to normalize tags/characters: accept array or comma-separated string
    const toJsonArray = (val: any): string | null => {
      if (!val) return null;
      if (Array.isArray(val)) return JSON.stringify(val);
      if (typeof val === 'string') {
        const trimmed = val.trim();
        if (!trimmed) return null;
        if (trimmed.startsWith('[')) {
          try { JSON.parse(trimmed); return trimmed; } catch { /* fall through */ }
        }
        return JSON.stringify(trimmed.split(',').map((s: string) => s.trim()).filter(Boolean));
      }
      return null;
    };

    const story = await prisma.story.create({
      data: {
        title,
        content,
        summary: summary || null,
        theme,
        style,
        targetAgeGroup,
        coverEmoji: coverEmoji || '📖',
        coverGradient: coverGradient || null,
        audioUrl: audioUrl || null,
        duration: duration || 0,
        wordCount: wordCount || 0,
        tags: toJsonArray(tags),
        characters: toJsonArray(characters),
        categoryId: categoryId || null,
        isPremium: isPremium || false,
        status: status || 'published',
        createdById: req.userId!,
      },
      include: { category: true },
    });

    return res.status(201).json({ code: 0, message: 'success', data: story });
  } catch (err) {
    next(err);
  }
};

// PUT /api/stories/:id - 更新故事
export const updateStory = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const {
      title,
      content,
      summary,
      theme,
      style,
      targetAgeGroup,
      coverEmoji,
      coverGradient,
      audioUrl,
      duration,
      wordCount,
      tags,
      characters,
      categoryId,
      isPremium,
      status,
    } = req.body;

    const existing = await prisma.story.findUnique({ where: { id } });
    if (!existing) {
      return fail(res, '故事不存在', 404);
    }

    const data: any = {};
    if (title !== undefined) data.title = title;
    if (content !== undefined) data.content = content;
    if (summary !== undefined) data.summary = summary;
    if (theme !== undefined) data.theme = theme;
    if (style !== undefined) data.style = style;
    if (targetAgeGroup !== undefined) data.targetAgeGroup = targetAgeGroup;
    if (coverEmoji !== undefined) data.coverEmoji = coverEmoji;
    if (coverGradient !== undefined) data.coverGradient = coverGradient;
    if (audioUrl !== undefined) data.audioUrl = audioUrl;
    if (duration !== undefined) data.duration = duration;
    if (wordCount !== undefined) data.wordCount = wordCount;
    if (tags !== undefined) {
      if (tags === null || tags === '') { data.tags = null; }
      else if (Array.isArray(tags)) { data.tags = JSON.stringify(tags); }
      else if (typeof tags === 'string') {
        const trimmed = tags.trim();
        if (trimmed.startsWith('[')) { try { JSON.parse(trimmed); data.tags = trimmed; } catch { data.tags = JSON.stringify(trimmed.split(',').map((s: string) => s.trim()).filter(Boolean)); } }
        else { data.tags = JSON.stringify(trimmed.split(',').map((s: string) => s.trim()).filter(Boolean)); }
      }
    }
    if (characters !== undefined) {
      if (characters === null || characters === '') { data.characters = null; }
      else if (Array.isArray(characters)) { data.characters = JSON.stringify(characters); }
      else if (typeof characters === 'string') {
        const trimmed = characters.trim();
        if (trimmed.startsWith('[')) { try { JSON.parse(trimmed); data.characters = trimmed; } catch { data.characters = JSON.stringify(trimmed.split(',').map((s: string) => s.trim()).filter(Boolean)); } }
        else { data.characters = JSON.stringify(trimmed.split(',').map((s: string) => s.trim()).filter(Boolean)); }
      }
    }
    if (categoryId !== undefined) data.categoryId = categoryId;
    if (isPremium !== undefined) data.isPremium = isPremium;
    if (status !== undefined) data.status = status;

    const story = await prisma.story.update({
      where: { id },
      data,
      include: { category: true },
    });

    success(res, story);
  } catch (err) {
    next(err);
  }
};

// DELETE /api/stories/:id - 删除故事
export const deleteStory = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;

    const existing = await prisma.story.findUnique({ where: { id } });
    if (!existing) {
      return fail(res, '故事不存在', 404);
    }

    await prisma.story.delete({ where: { id } });
    success(res, { message: '删除成功' });
  } catch (err) {
    next(err);
  }
};

// POST /api/stories/:id/audio - 上传故事音频
export const uploadStoryAudio = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    // 使用 multer 中间件处理上传（在路由中配置）
    // 这里假设 req.file 已经被 uploadAudio.single('audio') 填充
    if (!req.file) {
      return fail(res, '请上传音频文件', 400);
    }

    const { id } = req.params;
    const story = await prisma.story.findUnique({ where: { id } });
    if (!story) {
      return fail(res, '故事不存在', 404);
    }

    const audioUrl = `/api/files/audio/${req.file.filename}`;

    await prisma.story.update({
      where: { id },
      data: { audioUrl },
    });

    success(res, { audioUrl, filename: req.file.filename });
  } catch (err) {
    next(err);
  }
};

// POST /api/stories/categories - 创建分类
export const createCategory = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { name, icon, description, sortOrder } = req.body;
    if (!name) {
      return fail(res, '分类名称不能为空', 400);
    }

    const existing = await prisma.storyCategory.findUnique({ where: { name } });
    if (existing) {
      return fail(res, '分类已存在', 400);
    }

    const category = await prisma.storyCategory.create({
      data: {
        name,
        icon: icon || '📚',
        description: description || null,
        sortOrder: sortOrder || 0,
      },
    });

    return res.status(201).json({ code: 0, message: 'success', data: category });
  } catch (err) {
    next(err);
  }
};

// PUT /api/stories/categories/:id - 更新分类
export const updateCategory = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const { name, icon, description, sortOrder } = req.body;

    const existing = await prisma.storyCategory.findUnique({ where: { id } });
    if (!existing) {
      return fail(res, '分类不存在', 404);
    }

    const data: any = {};
    if (name !== undefined) data.name = name;
    if (icon !== undefined) data.icon = icon;
    if (description !== undefined) data.description = description;
    if (sortOrder !== undefined) data.sortOrder = sortOrder;

    const category = await prisma.storyCategory.update({
      where: { id },
      data,
    });

    success(res, category);
  } catch (err) {
    next(err);
  }
};

// DELETE /api/stories/categories/:id - 删除分类
export const deleteCategory = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;

    const existing = await prisma.storyCategory.findUnique({ where: { id } });
    if (!existing) {
      return fail(res, '分类不存在', 404);
    }

    // 将该分类下的故事 categoryId 置空
    await prisma.story.updateMany({
      where: { categoryId: id },
      data: { categoryId: null },
    });

    await prisma.storyCategory.delete({ where: { id } });
    success(res, { message: '删除成功' });
  } catch (err) {
    next(err);
  }
};

// ==================== 故事上传（含音频+字幕+封面） ====================

// POST /api/stories/upload - 完整上传故事（multipart/form-data）
// 字段: title, content, summary, theme, style, targetAgeGroup, coverEmoji, tags, characters,
//       categoryId, isPremium, status, duration, wordCount
// 文件: audio(音频), subtitle(字幕srt/vtt), cover(封面图)
export const uploadStory = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const files = req.files as { [fieldname: string]: Express.Multer.File[] } | undefined;
    const {
      title,
      content,
      summary,
      theme,
      style,
      targetAgeGroup,
      coverEmoji,
      tags,
      characters,
      categoryId,
      isPremium,
      status,
      duration,
      wordCount,
      subtitles: subtitlesText,
      subtitleFormat,
    } = req.body;

    if (!title) {
      return fail(res, '故事标题不能为空', 400);
    }
    if (!content) {
      return fail(res, '故事内容不能为空', 400);
    }
    if (!theme) {
      return fail(res, '请选择故事主题', 400);
    }
    if (!targetAgeGroup) {
      return fail(res, '请选择适合年龄段', 400);
    }

    // 处理 tags/characters：支持逗号分隔字符串或JSON数组字符串
    const processStringArrayField = (val: any): string | null => {
      if (!val) return null;
      if (typeof val === 'string') {
        const trimmed = val.trim();
        if (!trimmed) return null;
        // If it looks like a JSON array already, validate and return as-is
        if (trimmed.startsWith('[')) {
          try {
            const parsed = JSON.parse(trimmed);
            if (Array.isArray(parsed)) return trimmed;
          } catch { /* fall through to comma split */ }
        }
        // Otherwise treat as comma-separated
        return JSON.stringify(trimmed.split(',').map((s: string) => s.trim()).filter(Boolean));
      }
      if (Array.isArray(val)) return JSON.stringify(val);
      return null;
    };

    // 处理音频文件
    let audioUrl: string | null = null;
    let audioDuration = parseInt(duration) || 0;
    if (files?.audio?.[0]) {
      audioUrl = `/api/files/audio/${files.audio[0].filename}`;
    }

    // 处理封面图
    let coverImageUrl: string | null = null;
    if (files?.cover?.[0]) {
      coverImageUrl = `/api/files/covers/${files.cover[0].filename}`;
    }

    // 处理字幕
    let subtitleUrl: string | null = null;
    let subtitleFmt: string | null = null;
    let subtitlesJson: string | null = null;

    if (files?.subtitle?.[0]) {
      const subtitleFile = files.subtitle[0];
      subtitleUrl = `/api/files/subtitles/${subtitleFile.filename}`;
      const ext = path.extname(subtitleFile.originalname).toLowerCase().replace('.', '');
      subtitleFmt = ext || 'srt';

      try {
        const subContent = fs.readFileSync(subtitleFile.path, 'utf-8');
        const { cues } = parseSubtitle(subContent, subtitleFile.originalname);
        if (cues.length > 0) {
          subtitlesJson = cuesToJSON(cues);
          if (!audioDuration) {
            audioDuration = Math.ceil(cues[cues.length - 1].endTime);
          }
        }
      } catch (e) {
        // subtitle parse failure doesn't block story creation
      }
    } else if (subtitlesText) {
      const fmt = subtitleFormat || 'srt';
      subtitleFmt = fmt;
      try {
        const { cues } = parseSubtitle(subtitlesText);
        if (cues.length > 0) {
          subtitlesJson = cuesToJSON(cues);
          if (!audioDuration) {
            audioDuration = Math.ceil(cues[cues.length - 1].endTime);
          }
        }
      } catch (e) {
        // subtitle parse failure doesn't block
      }
    }

    // 计算字数
    const storyContent = content || '';
    const wc = wordCount ? parseInt(wordCount) : storyContent.replace(/\s/g, '').length;

    const story = await prisma.story.create({
      data: {
        title: title.trim(),
        content: storyContent,
        summary: summary || null,
        theme,
        style: style || 'warm',
        targetAgeGroup,
        coverEmoji: coverEmoji || '📖',
        coverImageUrl,
        audioUrl,
        subtitleUrl,
        subtitleFormat: subtitleFmt,
        subtitles: subtitlesJson,
        duration: audioDuration,
        wordCount: wc,
        tags: processStringArrayField(tags),
        characters: processStringArrayField(characters),
        categoryId: categoryId || null,
        isPremium: isPremium === 'true' || isPremium === true,
        status: status || 'published',
        createdById: req.userId!,
      },
      include: { category: true },
    });

    return res.status(201).json({
      code: 0,
      message: '故事上传成功',
      data: {
        ...story,
        subtitles: story.subtitles ? cuesFromJSON(story.subtitles) : null,
      },
    });
  } catch (err) {
    next(err);
  }
};

// POST /api/stories/:id/subtitle - 上传/更新字幕
export const uploadSubtitle = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const story = await prisma.story.findUnique({ where: { id } });
    if (!story) {
      return fail(res, '故事不存在', 404);
    }

    let subtitlesJson: string | null = null;
    let subtitleUrl: string | null = null;
    let subtitleFmt: string | null = null;

    const file = (req.files as any)?.subtitle?.[0] || (req.file as Express.Multer.File);
    const { subtitles: subtitlesText, subtitleFormat } = req.body;

    if (file) {
      subtitleUrl = `/api/files/subtitles/${file.filename}`;
      const ext = path.extname(file.originalname).toLowerCase().replace('.', '');
      subtitleFmt = ext || 'srt';

      try {
        const content = fs.readFileSync(file.path, 'utf-8');
        const { cues } = parseSubtitle(content, file.originalname);
        if (cues.length > 0) {
          subtitlesJson = cuesToJSON(cues);
        }
      } catch (e) {
        // 解析失败
      }
    } else if (subtitlesText) {
      subtitleFmt = subtitleFormat || 'srt';
      try {
        const { cues } = parseSubtitle(subtitlesText);
        if (cues.length > 0) {
          subtitlesJson = cuesToJSON(cues);
        }
      } catch (e) {
        return fail(res, '字幕解析失败，请检查格式', 400);
      }
    } else {
      return fail(res, '请上传字幕文件或提供字幕内容', 400);
    }

    const updated = await prisma.story.update({
      where: { id },
      data: {
        subtitleUrl,
        subtitleFormat: subtitleFmt,
        subtitles: subtitlesJson,
        // 如果没有设置 duration，用字幕最后时间
        ...(story.duration === 0 && subtitlesJson ? {
          duration: Math.ceil(cuesFromJSON(subtitlesJson).slice(-1)[0]?.endTime || 0)
        } : {}),
      },
    });

    success(res, {
      message: '字幕上传成功',
      subtitleUrl,
      subtitleFormat: subtitleFmt,
      cues: subtitlesJson ? cuesFromJSON(subtitlesJson).length : 0,
      subtitles: subtitlesJson ? cuesFromJSON(subtitlesJson) : null,
    });
  } catch (err) {
    next(err);
  }
};

// GET /api/stories/:id/subtitles - 获取故事字幕（解析后的 JSON）
export const getStorySubtitles = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const story = await prisma.story.findUnique({ where: { id } });
    if (!story) {
      return fail(res, '故事不存在', 404);
    }

    if (story.subtitles) {
      const cues = cuesFromJSON(story.subtitles);
      return success(res, {
        format: story.subtitleFormat,
        cues,
        count: cues.length,
      });
    }

    if (story.subtitleUrl) {
      // 从文件读取并解析
      const filename = story.subtitleUrl.split('/').pop();
      if (filename) {
        const filePath = path.join(uploadDirs.subtitles, filename);
        if (fs.existsSync(filePath)) {
          const content = fs.readFileSync(filePath, 'utf-8');
          const { cues, format } = parseSubtitle(content, filename);
          return success(res, { format, cues, count: cues.length });
        }
      }
    }

    return success(res, { format: null, cues: [], count: 0 });
  } catch (err) {
    next(err);
  }
};

// PUT /api/stories/:id/subtitles - 更新字幕（手动编辑）
export const updateSubtitles = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const { cues } = req.body;

    const story = await prisma.story.findUnique({ where: { id } });
    if (!story) {
      return fail(res, '故事不存在', 404);
    }

    if (!Array.isArray(cues)) {
      return fail(res, '字幕格式不正确', 400);
    }

    const formattedCues: SubtitleCue[] = cues.map((c: any, i: number) => ({
      index: i + 1,
      startTime: c.startTime ?? c.s ?? 0,
      endTime: c.endTime ?? c.e ?? 0,
      startTimeStr: '',
      endTimeStr: '',
      text: c.text ?? c.t ?? '',
    }));

    const subtitlesJson = cuesToJSON(formattedCues);

    await prisma.story.update({
      where: { id },
      data: {
        subtitles: subtitlesJson,
        subtitleFormat: 'json',
        duration: Math.ceil(formattedCues[formattedCues.length - 1]?.endTime || story.duration),
      },
    });

    success(res, { message: '字幕更新成功', count: formattedCues.length, cues: formattedCues });
  } catch (err) {
    next(err);
  }
};
