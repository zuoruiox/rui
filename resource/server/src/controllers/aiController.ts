import { Request, Response, NextFunction } from 'express';
import { prisma } from '../utils/prisma';
import { success, fail } from '../utils/response';
import { AuthRequest } from '../middlewares/auth';
import { generateStoryWithQwen } from '../services/qwenService';

// POST /api/ai/generate - AI生成故事
export const generateStory = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { theme, style, targetAge, wordCount, characters, childName, customPrompt, voiceModelId } = req.body;

    if (!theme || !style || !targetAge) {
      return fail(res, '主题、风格和适合年龄不能为空', 400);
    }

    const wc = parseInt(wordCount) || 500;
    const chars = Array.isArray(characters) ? characters : (characters ? [characters] : []);
    if (childName && !chars.includes(childName)) {
      chars.push(childName);
    }

    // 调用 Qwen 生成故事
    const story = await generateStoryWithQwen({
      theme,
      style,
      targetAge,
      wordCount: wc,
      characters: chars,
      childName,
      customPrompt
    });

    // 保存到数据库
    const aiStory = await prisma.aIStory.create({
      data: {
        userId: req.userId!,
        title: story.title,
        content: story.content,
        theme,
        style,
        targetAgeGroup: targetAge,
        characters: JSON.stringify(story.characters.length > 0 ? story.characters : chars),
        prompt: customPrompt || null,
        length: wc <= 300 ? 'short' : wc <= 600 ? 'medium' : 'long',
        duration: story.suggestedDuration,
        voiceModelId: voiceModelId || null,
        status: 'completed',
        isPublic: false,
      }
    });

    return success(res, {
      storyId: aiStory.id,
      title: story.title,
      content: story.content,
      summary: story.summary,
      wordCount: story.wordCount,
      suggestedDuration: story.suggestedDuration,
      tags: story.tags,
      characters: story.characters.length > 0 ? story.characters : chars,
      coverEmoji: story.coverEmoji,
      coverGradient: null,
      createdAt: aiStory.createdAt
    }, '故事生成成功');
  } catch (err: any) {
    next(err);
  }
};

// GET /api/ai/my-stories - 获取我的AI故事列表
export const myStories = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const stories = await prisma.aIStory.findMany({
      where: { userId: req.userId! },
      orderBy: { createdAt: 'desc' },
      take: 50
    });

    const list = stories.map(s => ({
      storyId: s.id,
      title: s.title,
      content: s.content,
      summary: s.content.substring(0, 80) + '...',
      wordCount: s.content.replace(/\s/g, '').length,
      suggestedDuration: s.duration || 0,
      tags: [],
      characters: safeParse(s.characters, []),
      coverEmoji: '📖',
      audioUrl: s.audioUrl,
      status: s.status,
      createdAt: s.createdAt
    }));

    return success(res, list);
  } catch (err) {
    next(err);
  }
};

function safeParse<T>(str: string | null, fallback: T): T {
  if (!str) return fallback;
  try { return JSON.parse(str) as T; } catch { return fallback; }
}