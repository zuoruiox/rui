import { Request, Response, NextFunction } from 'express';
import fs from 'fs';
import path from 'path';
import FormData from 'form-data';
import fetch from 'node-fetch';
import { prisma } from '../utils/prisma';
import { success, fail, paginated } from '../utils/response';
import { AuthRequest } from '../middlewares/auth';
import { uploadAudio, uploadDirs } from '../middlewares/upload';

// TTS 服务地址
const TTS_API_URL = process.env.TTS_API_URL || 'http://10.86.18.13:8000/tts';

// 快速模式需要 1 段录音，高质量模式需要 3 段
const REQUIRED_RECORDINGS: Record<string, number> = {
  quick: 1,
  high: 3,
};

// ==================== 用户接口 ====================

// GET /api/voices - 我的声音模型列表
export const listVoiceModels = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const voiceModels = await prisma.voiceModel.findMany({
      where: { userId: req.userId! },
      orderBy: { updatedAt: 'desc' },
      include: {
        _count: { select: { recordings: true } },
      },
    });

    const list = voiceModels.map(v => ({
      ...v,
      recordingCount: v._count.recordings,
    }));

    success(res, list);
  } catch (err) {
    next(err);
  }
};

// GET /api/voices/:id - 声音模型详情
export const getVoiceModel = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;

    const voiceModel = await prisma.voiceModel.findUnique({
      where: { id },
      include: {
        recordings: { orderBy: { sortOrder: 'asc' } },
      },
    });

    if (!voiceModel) {
      return fail(res, '声音模型不存在', 404);
    }

    // 非管理员只能查看自己的
    if (voiceModel.userId !== req.userId && req.userRole !== 'admin') {
      return fail(res, '无权访问', 403);
    }

    success(res, voiceModel);
  } catch (err) {
    next(err);
  }
};

// POST /api/voices - 创建声音模型
export const createVoiceModel = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { name, ownerType, type, emoji, quality, description } = req.body;
    if (!name) {
      return fail(res, '名称不能为空', 400);
    }

    // 兼容前端传 type 字段
    let resolvedOwnerType = ownerType || type || 'mom';
    const typeMap: Record<string, string> = { female: 'mom', male: 'dad', child: 'child', custom: 'custom' };
    resolvedOwnerType = typeMap[resolvedOwnerType] || resolvedOwnerType;

    const voiceModel = await prisma.voiceModel.create({
      data: {
        userId: req.userId!,
        name,
        ownerType: resolvedOwnerType,
        emoji: emoji || '🎤',
        quality: quality || 'quick',
        status: 'draft',
        progress: 0,
      },
      include: {
        _count: { select: { recordings: true } },
      },
    });

    return res.status(201).json({ code: 0, message: 'success', data: voiceModel });
  } catch (err) {
    next(err);
  }
};

// POST /api/voices/:id/recordings - 上传录音样本
export const uploadRecording = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    if (!req.file) {
      return fail(res, '请上传录音文件', 400);
    }

    const { id } = req.params;
    const { promptText, duration, quality } = req.body;

    const voiceModel = await prisma.voiceModel.findUnique({
      where: { id },
      include: { _count: { select: { recordings: true } } },
    });

    if (!voiceModel) {
      return fail(res, '声音模型不存在', 404);
    }
    if (voiceModel.userId !== req.userId) {
      return fail(res, '无权操作', 403);
    }

    const filePath = `/api/files/recordings/${req.file.filename}`;
    const recordingCount = voiceModel._count.recordings;

    const recording = await prisma.recordingSample.create({
      data: {
        voiceModelId: id,
        filePath,
        duration: duration ? parseFloat(duration) : 0,
        fileSize: req.file.size,
        quality: quality || null,
        promptText: promptText || null,
        sortOrder: recordingCount,
      },
    });

    // 更新 progress
    const required = REQUIRED_RECORDINGS[voiceModel.quality || 'quick'] || 1;
    const newCount = recordingCount + 1;
    const progress = Math.min(newCount / required, 1);

    await prisma.voiceModel.update({
      where: { id },
      data: {
        progress,
        status: newCount >= required ? 'ready' : 'recording',
      },
    });

    return res.status(201).json({ code: 0, message: 'success', data: { recording, progress, recordedCount: newCount, requiredCount: required } });
  } catch (err) {
    next(err);
  }
};

// DELETE /api/voices/recordings/:id - 删除录音样本
export const deleteRecording = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;

    const recording = await prisma.recordingSample.findUnique({
      where: { id },
      include: { voiceModel: true },
    });

    if (!recording) {
      return fail(res, '录音不存在', 404);
    }
    if (recording.voiceModel.userId !== req.userId) {
      return fail(res, '无权操作', 403);
    }

    // 删除磁盘文件
    try {
      // filePath 格式: /api/files/recordings/filename
      const filename = path.basename(recording.filePath);
      const fullPath = path.join(uploadDirs.recordings, filename);
      if (fs.existsSync(fullPath)) {
        fs.unlinkSync(fullPath);
      }
    } catch (e) {
      // 忽略文件删除错误
    }

    await prisma.recordingSample.delete({ where: { id } });

    // 更新 progress
    const remainingCount = await prisma.recordingSample.count({
      where: { voiceModelId: recording.voiceModelId },
    });
    const required = REQUIRED_RECORDINGS[recording.voiceModel.quality || 'quick'] || 1;
    const progress = Math.min(remainingCount / required, 1);

    await prisma.voiceModel.update({
      where: { id: recording.voiceModelId },
      data: {
        progress,
        status: remainingCount === 0 ? 'draft' : remainingCount >= required ? 'ready' : 'recording',
      },
    });

    success(res, { message: '删除成功' });
  } catch (err) {
    next(err);
  }
};

// POST /api/voices/:id/train - 开始训练
export const startTraining = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;

    const voiceModel = await prisma.voiceModel.findUnique({
      where: { id },
      include: { _count: { select: { recordings: true } } },
    });

    if (!voiceModel) {
      return fail(res, '声音模型不存在', 404);
    }
    if (voiceModel.userId !== req.userId) {
      return fail(res, '无权操作', 403);
    }

    const required = REQUIRED_RECORDINGS[voiceModel.quality || 'quick'] || 1;
    if (voiceModel._count.recordings < required) {
      return fail(res, `录音数量不足，需要 ${required} 段，当前 ${voiceModel._count.recordings} 段`, 400);
    }

    // 立即更新为 training 状态
    await prisma.voiceModel.update({
      where: { id },
      data: { status: 'training', progress: 0.9 },
    });

    // 模拟训练：5 秒后改为 ready
    setTimeout(async () => {
      try {
        const previewUrl = `/api/files/voices/preview_${id}_${Date.now()}.mp3`;
        await prisma.voiceModel.update({
          where: { id },
          data: {
            status: 'ready',
            progress: 1,
            previewUrl,
            trainedAt: new Date(),
          },
        });
      } catch (e) {
        // 忽略异步错误
      }
    }, 5000);

    success(res, { message: '训练已开始', status: 'training' });
  } catch (err) {
    next(err);
  }
};

// DELETE /api/voices/:id - 删除声音模型
export const deleteVoiceModel = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;

    const voiceModel = await prisma.voiceModel.findUnique({
      where: { id },
      include: { recordings: true },
    });

    if (!voiceModel) {
      return fail(res, '声音模型不存在', 404);
    }
    if (voiceModel.userId !== req.userId && req.userRole !== 'admin') {
      return fail(res, '无权操作', 403);
    }

    // 删除所有关联的录音文件
    for (const recording of voiceModel.recordings) {
      try {
        const filename = path.basename(recording.filePath);
        const fullPath = path.join(uploadDirs.recordings, filename);
        if (fs.existsSync(fullPath)) {
          fs.unlinkSync(fullPath);
        }
      } catch (e) {
        // 忽略文件删除错误
      }
    }

    // 删除 preview 文件
    if (voiceModel.previewUrl) {
      try {
        const filename = path.basename(voiceModel.previewUrl);
        const fullPath = path.join(uploadDirs.voices, filename);
        if (fs.existsSync(fullPath)) {
          fs.unlinkSync(fullPath);
        }
      } catch (e) {
        // 忽略
      }
    }

    await prisma.voiceModel.delete({ where: { id } });
    success(res, { message: '删除成功' });
  } catch (err) {
    next(err);
  }
};

// POST /api/voices/synthesize - 合成语音（调用外部 TTS 服务）
export const synthesizeSpeech = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { voiceModelId, text, language } = req.body;
    if (!voiceModelId || !text) {
      return fail(res, 'voiceModelId 和 text 不能为空', 400);
    }

    const voiceModel = await prisma.voiceModel.findUnique({
      where: { id: voiceModelId },
      include: { recordings: { orderBy: { sortOrder: 'asc' } } },
    });
    if (!voiceModel) {
      return fail(res, '声音模型不存在', 404);
    }
    if (voiceModel.userId !== req.userId && req.userRole !== 'admin') {
      return fail(res, '无权使用该声音模型', 403);
    }
    if (voiceModel.status !== 'ready') {
      return fail(res, '声音模型尚未训练完成', 400);
    }
    if (!voiceModel.recordings || voiceModel.recordings.length === 0) {
      return fail(res, '该声音模型没有录音样本', 400);
    }

    // 取第一段录音作为参考音频
    const refRecording = voiceModel.recordings[0];
    const refFilename = path.basename(refRecording.filePath);
    const refAudioPath = path.join(uploadDirs.recordings, refFilename);
    if (!fs.existsSync(refAudioPath)) {
      return fail(res, '参考音频文件不存在', 500);
    }

    // 参考文本：优先用录音时的 promptText，否则用默认文本
    const refText = refRecording.promptText || '从前有一只可爱的小兔子，住在森林深处的蘑菇房子里。';

    // 构建 form-data 请求到 TTS 服务
    const form = new FormData();
    form.append('ref_text', refText);
    form.append('text', text);
    form.append('language', language || 'zh');

    // 确定文件 MIME 类型
    const ext = path.extname(refAudioPath).toLowerCase();
    let contentType = 'audio/wav';
    if (ext === '.m4a' || ext === '.mp4' || ext === '.aac') contentType = 'audio/mp4';
    else if (ext === '.mp3') contentType = 'audio/mpeg';
    else if (ext === '.ogg') contentType = 'audio/ogg';
    else if (ext === '.webm') contentType = 'audio/webm';

    form.append('ref_audio', fs.createReadStream(refAudioPath), {
      filename: path.basename(refAudioPath),
      contentType,
    });

    // 调用 TTS 服务（声音克隆耗时较长，设置 5 分钟超时）
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 300000);

    let ttsResponse;
    try {
      ttsResponse = await fetch(TTS_API_URL, {
        method: 'POST',
        body: form as any,
        headers: form.getHeaders(),
        signal: controller.signal,
      } as any);
    } finally {
      clearTimeout(timeoutId);
    }

    if (!ttsResponse.ok) {
      const errText = await ttsResponse.text();
      console.error('TTS 服务调用失败:', ttsResponse.status, errText);
      return fail(res, `语音合成失败: ${ttsResponse.status} - ${errText.substring(0, 200)}`, 500);
    }

    // 获取音频数据并保存
    const audioBuffer = await ttsResponse.buffer();
    const outputFilename = `synth_${voiceModelId}_${Date.now()}.wav`;
    const outputPath = path.join(uploadDirs.audio, outputFilename);
    fs.writeFileSync(outputPath, audioBuffer);

    const audioUrl = `/api/files/audio/${outputFilename}`;
    const duration = Math.ceil(text.length / 4); // 粗略估算：中文每秒约4字

    success(res, {
      audioUrl,
      duration,
      voiceModelId,
      format: 'wav',
    });
  } catch (err) {
    console.error('TTS 合成异常:', err);
    next(err);
  }
};

// ==================== 管理员接口 ====================

// GET /api/voices/all - 所有声音模型（管理员）
export const listAllVoiceModels = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const pageSize = Math.min(100, Math.max(1, parseInt(req.query.pageSize as string) || 20));
    const status = req.query.status as string | undefined;

    const where: any = {};
    if (status) where.status = status;

    const [voiceModels, total] = await Promise.all([
      prisma.voiceModel.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * pageSize,
        take: pageSize,
        include: {
          user: { select: { id: true, nickname: true, email: true } },
          _count: { select: { recordings: true } },
        },
      }),
      prisma.voiceModel.count({ where }),
    ]);

    const list = voiceModels.map(v => ({
      ...v,
      userNickname: v.user?.nickname || v.user?.email || '-',
      recordingCount: v._count.recordings,
    }));

    paginated(res, list, total, page, pageSize);
  } catch (err) {
    next(err);
  }
};
