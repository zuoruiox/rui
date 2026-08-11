import { Router } from 'express';
import { authRequired, adminRequired } from '../middlewares/auth';
import { uploadAudio } from '../middlewares/upload';
import {
  listVoiceModels,
  getVoiceModel,
  createVoiceModel,
  uploadRecording,
  deleteRecording,
  startTraining,
  deleteVoiceModel,
  synthesizeSpeech,
  listAllVoiceModels,
} from '../controllers/voiceController';

const router = Router();

// 我的声音模型列表
router.get('/', authRequired, listVoiceModels);

// 创建声音模型
router.post('/', authRequired, createVoiceModel);

// 合成语音
router.post('/synthesize', authRequired, synthesizeSpeech);

// 管理员：所有声音模型
router.get('/all', authRequired, adminRequired, listAllVoiceModels);

// 声音模型详情
router.get('/:id', authRequired, getVoiceModel);

// 上传录音样本
router.post(
  '/:id/recordings',
  authRequired,
  uploadAudio.single('recording'),
  uploadRecording
);

// 开始训练
router.post('/:id/train', authRequired, startTraining);

// 删除声音模型
router.delete('/:id', authRequired, deleteVoiceModel);

// 删除录音样本
router.delete('/recordings/:id', authRequired, deleteRecording);

export default router;
