import { Response } from 'express';

export function success<T>(res: Response, data: T, message = 'success', status = 200) {
  return res.status(status).json({ code: 0, message, data });
}

export function fail(res: Response, message: string, code = 1, status?: number) {
  // If code looks like an HTTP error status (4xx/5xx) and no explicit status given, use code as status
  let httpStatus = status;
  if (!httpStatus) {
    if (code >= 400 && code < 600) {
      httpStatus = code;
    } else {
      httpStatus = 400;
    }
  }
  return res.status(httpStatus).json({ code, message, data: null });
}

export function paginated<T>(res: Response, list: T[], total: number, page: number, pageSize: number) {
  return res.json({
    code: 0,
    message: 'success',
    data: {
      list,
      pagination: { page, pageSize, total, totalPages: Math.ceil(total / pageSize) },
    },
  });
}
