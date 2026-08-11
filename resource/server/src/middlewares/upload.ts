import multer from 'multer';
import path from 'path';
import fs from 'fs';
import { v4 as uuidv4 } from 'uuid';

const UPLOAD_DIR = process.env.UPLOAD_DIR || './uploads';

// 确保上传目录存在
const dirs = {
  audio: path.join(UPLOAD_DIR, 'audio'),
  recordings: path.join(UPLOAD_DIR, 'recordings'),
  voices: path.join(UPLOAD_DIR, 'voices'),
  avatars: path.join(UPLOAD_DIR, 'avatars'),
  covers: path.join(UPLOAD_DIR, 'covers'),
  subtitles: path.join(UPLOAD_DIR, 'subtitles'),
};

Object.values(dirs).forEach(dir => {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
});

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    let dir = dirs.audio;
    if (file.fieldname === 'recording') dir = dirs.recordings;
    else if (file.fieldname === 'avatar') dir = dirs.avatars;
    else if (file.fieldname === 'cover') dir = dirs.covers;
    else if (file.fieldname === 'voiceModel') dir = dirs.voices;
    else if (file.fieldname === 'subtitle' || file.fieldname === 'subtitles') dir = dirs.subtitles;
    cb(null, dir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.bin';
    cb(null, `${uuidv4()}${ext}`);
  },
});

const audioFileFilter = (req: any, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
  const allowed = ['.mp3', '.wav', '.m4a', '.aac', '.ogg', '.flac'];
  const ext = path.extname(file.originalname).toLowerCase();
  if (allowed.includes(ext) || file.mimetype.startsWith('audio/')) {
    cb(null, true);
  } else {
    cb(new Error('只支持音频文件格式（mp3/wav/m4a/aac/ogg/flac）'));
  }
};

const imageFileFilter = (req: any, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
  const allowed = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg'];
  const ext = path.extname(file.originalname).toLowerCase();
  if (allowed.includes(ext) || file.mimetype.startsWith('image/')) {
    cb(null, true);
  } else {
    cb(new Error('只支持图片文件格式'));
  }
};

const subtitleFileFilter = (req: any, file: Express.Multer.File, cb: multer.FileFilterCallback) => {
  const allowed = ['.srt', '.vtt', '.lrc', '.ass', '.ssa'];
  const ext = path.extname(file.originalname).toLowerCase();
  if (allowed.includes(ext) || file.mimetype.startsWith('text/')) {
    cb(null, true);
  } else {
    cb(new Error('只支持字幕文件格式（srt/vtt/lrc/ass）'));
  }
};

export const uploadAudio = multer({
  storage,
  fileFilter: audioFileFilter,
  limits: { fileSize: 200 * 1024 * 1024 }, // 200MB
});

export const uploadImage = multer({
  storage,
  fileFilter: imageFileFilter,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
});

export const uploadSubtitle = multer({
  storage,
  fileFilter: subtitleFileFilter,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
});

export const uploadStoryFiles = multer({
  storage,
  limits: { fileSize: 200 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    const audioExts = ['.mp3', '.wav', '.m4a', '.aac', '.ogg', '.flac'];
    const subtitleExts = ['.srt', '.vtt', '.lrc', '.ass', '.ssa'];
    const imageExts = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg'];
    if (file.fieldname === 'audio' && (audioExts.includes(ext) || file.mimetype.startsWith('audio/'))) {
      return cb(null, true);
    }
    if ((file.fieldname === 'subtitle' || file.fieldname === 'subtitles') && (subtitleExts.includes(ext) || file.mimetype.startsWith('text/'))) {
      return cb(null, true);
    }
    if (file.fieldname === 'cover' && (imageExts.includes(ext) || file.mimetype.startsWith('image/'))) {
      return cb(null, true);
    }
    cb(new Error(`不支持的文件类型: ${file.originalname}`));
  },
});

export const uploadAny = multer({
  storage,
  limits: { fileSize: 200 * 1024 * 1024 },
});

export { dirs as uploadDirs };
