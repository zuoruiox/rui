import { Request, Response, NextFunction } from 'express';
import fs from 'fs';
import path from 'path';
import { success, fail } from '../utils/response';
import { AuthRequest } from '../middlewares/auth';
import { uploadDirs } from '../middlewares/upload';

// 类型到目录的映射
const TYPE_TO_DIR: Record<string, string> = {
  audio: uploadDirs.audio,
  recordings: uploadDirs.recordings,
  voices: uploadDirs.voices,
  avatars: uploadDirs.avatars,
  covers: uploadDirs.covers,
  subtitles: uploadDirs.subtitles,
};

// 根据扩展名获取 Content-Type
function getContentType(filename: string): string {
  const ext = path.extname(filename).toLowerCase();
  const map: Record<string, string> = {
    '.mp3': 'audio/mpeg',
    '.wav': 'audio/wav',
    '.ogg': 'audio/ogg',
    '.m4a': 'audio/mp4',
    '.aac': 'audio/aac',
    '.flac': 'audio/flac',
    '.webm': 'audio/webm',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.svg': 'image/svg+xml',
    '.srt': 'text/plain; charset=utf-8',
    '.vtt': 'text/vtt; charset=utf-8',
    '.lrc': 'text/plain; charset=utf-8',
    '.ass': 'text/plain; charset=utf-8',
    '.ssa': 'text/plain; charset=utf-8',
    '.json': 'application/json',
  };
  return map[ext] || 'application/octet-stream';
}

// GET /api/files/:type/:filename - 静态文件服务
export const serveFile = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { type, filename } = req.params;

    const dir = TYPE_TO_DIR[type];
    if (!dir) {
      return fail(res, '不支持的文件类型', 400);
    }

    // 防止路径遍历
    const safeFilename = path.basename(filename);
    const filePath = path.join(dir, safeFilename);

    if (!fs.existsSync(filePath)) {
      return fail(res, '文件不存在', 404);
    }

    const contentType = getContentType(safeFilename);
    res.setHeader('Content-Type', contentType);

    // 对于音频文件，支持 Range 请求
    if (contentType.startsWith('audio/')) {
      const stat = fs.statSync(filePath);
      const fileSize = stat.size;
      const range = req.headers.range;

      if (range) {
        const parts = range.replace(/bytes=/, '').split('-');
        const start = parseInt(parts[0], 10);
        const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
        const chunkSize = end - start + 1;

        res.writeHead(206, {
          'Content-Range': `bytes ${start}-${end}/${fileSize}`,
          'Accept-Ranges': 'bytes',
          'Content-Length': chunkSize,
          'Content-Type': contentType,
        });

        const stream = fs.createReadStream(filePath, { start, end });
        stream.pipe(res);
      } else {
        res.setHeader('Content-Length', fileSize);
        const stream = fs.createReadStream(filePath);
        stream.pipe(res);
      }
    } else {
      const stat = fs.statSync(filePath);
      res.setHeader('Content-Length', stat.size);
      const stream = fs.createReadStream(filePath);
      stream.pipe(res);
    }
  } catch (err) {
    next(err);
  }
};

// POST /api/files/avatar - 上传头像
export const uploadAvatar = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    if (!req.file) {
      return fail(res, '请上传图片文件', 400);
    }

    const fileUrl = `/api/files/avatars/${req.file.filename}`;

    const { prisma } = await import('../utils/prisma');
    await prisma.user.update({
      where: { id: req.userId! },
      data: { avatar: fileUrl },
    });

    success(res, { url: fileUrl, filename: req.file.filename });
  } catch (err) {
    next(err);
  }
};

// POST /api/files/cover - 上传封面
export const uploadCover = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    if (!req.file) {
      return fail(res, '请上传图片文件', 400);
    }

    const fileUrl = `/api/files/covers/${req.file.filename}`;
    success(res, { url: fileUrl, filename: req.file.filename });
  } catch (err) {
    next(err);
  }
};

// GET /api/files/list/:type - 列出某类型的文件（管理员）
export const listFiles = async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { type } = req.params;
    const dir = TYPE_TO_DIR[type];
    if (!dir) {
      return fail(res, '不支持的文件类型', 400);
    }

    if (!fs.existsSync(dir)) {
      return success(res, { files: [] });
    }

    const files = fs.readdirSync(dir).map(filename => {
      const filePath = path.join(dir, filename);
      try {
        const stat = fs.statSync(filePath);
        if (stat.isFile()) {
          return {
            name: filename,
            size: stat.size,
            createdAt: stat.birthtime,
            url: `/api/files/${type}/${filename}`,
          };
        }
      } catch {
        // skip unreadable files
      }
      return null;
    }).filter((f): f is NonNullable<typeof f> => f !== null).sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

    success(res, { files });
  } catch (err) {
    next(err);
  }
};
