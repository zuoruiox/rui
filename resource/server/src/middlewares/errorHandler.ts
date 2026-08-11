import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';
import { fail } from '../utils/response';

export function errorHandler(err: Error, req: Request, res: Response, next: NextFunction) {
  logger.error('请求错误:', err.message, err.stack);
  if (err.message.includes('只支持')) {
    return fail(res, err.message, 400, 400);
  }
  return fail(res, err.message || '服务器内部错误', 500, 500);
}
