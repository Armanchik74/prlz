export class HttpError extends Error {
  constructor(
    public readonly statusCode: number,
    public readonly code: string,
    message: string
  ) {
    super(message);
  }
}

export const notFound = (message = "Объект не найден") => new HttpError(404, "NOT_FOUND", message);
export const unauthorized = () => new HttpError(401, "UNAUTHORIZED", "Требуется авторизация");
export const conflict = (message: string) => new HttpError(409, "CONFLICT", message);
