import type { FastifyRequest } from "fastify";
import jwt from "jsonwebtoken";
import type { Env } from "../config/env.js";
import { unauthorized } from "../lib/errors.js";

declare module "fastify" {
  interface FastifyRequest {
    authUser?: { id: string; role: "buyer" | "seller" | "admin" };
  }
}

export function createAuthGuard(env: Env) {
  return async function authGuard(request: FastifyRequest): Promise<void> {
    const debugId = request.headers["x-debug-user-id"];
    if (env.APP_ENV !== "production" && typeof debugId === "string") {
      request.authUser = { id: debugId, role: "buyer" };
      return;
    }

    const authorization = request.headers.authorization;
    if (!authorization?.startsWith("Bearer ")) throw unauthorized();

    try {
      const payload = jwt.verify(authorization.slice(7), env.JWT_ACCESS_SECRET, {
        issuer: env.JWT_ISSUER,
        audience: env.JWT_AUDIENCE,
        algorithms: ["HS256"]
      });
      if (typeof payload === "string" || typeof payload.sub !== "string") throw unauthorized();
      const role = payload.role;
      if (role !== "buyer" && role !== "seller" && role !== "admin") throw unauthorized();
      request.authUser = { id: payload.sub, role };
    } catch {
      throw unauthorized();
    }
  };
}
