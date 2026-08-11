import { Request, Response, NextFunction } from 'express';
import { verifyToken } from '../utils/jwt';
import { fail } from '../utils/response';

export interface AuthRequest extends Request {
  userId?: string;
  userRole?: string;
}

export function authRequired(req: AuthRequest, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return fail(res, '未登录，请先登录', 401, 401);
  }
  try {
    const token = authHeader.slice(7);
    const payload = verifyToken(token);
    req.userId = payload.userId;
    req.userRole = payload.role;
    next();
  } catch {
    return fail(res, '登录已过期，请重新登录', 401, 401);
  }
}

export function adminRequired(req: AuthRequest, res: Response, next: NextFunction) {
  if (req.userRole !== 'admin') {
    return fail(res, '需要管理员权限', 403, 403);
  }
  next();
}

export function optionalAuth(req: AuthRequest, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;
  if (authHeader && authHeader.startsWith('Bearer ')) {
    try {
      const token = authHeader.slice(7);
      const payload = verifyToken(token);
      req.userId = payload.userId;
      req.userRole = payload.role;
    } catch {
      // ignore invalid token
    }
  }
  next();
}
