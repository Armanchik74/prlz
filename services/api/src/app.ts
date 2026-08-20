import cors from "@fastify/cors";
import helmet from "@fastify/helmet";
import rateLimit from "@fastify/rate-limit";
import Fastify from "fastify";
import type { Env } from "./config/env.js";
import type { Database } from "./db/pool.js";
import { HttpError } from "./lib/errors.js";
import { PiiCipher } from "./lib/pii.js";
import { createAuthGuard } from "./middleware/auth.js";
import { catalogRoutes } from "./routes/catalog.js";
import { favoriteRoutes } from "./routes/favorites.js";
import { healthRoutes } from "./routes/health.js";
import { profileRoutes } from "./routes/profile.js";
import { reservationRoutes } from "./routes/reservations.js";

export async function buildApp(env: Env, db: Database) {
  const app = Fastify({
    trustProxy: true,
    bodyLimit: 1_000_000,
    requestIdHeader: "x-request-id",
    logger: {
      level: env.LOG_LEVEL,
      redact: {
        paths: [
          "req.headers.authorization",
          "req.headers.cookie",
          "req.body.phone",
          "req.body.name",
          "res.headers.set-cookie"
        ],
        censor: "[REDACTED]"
      }
    }
  });

  await app.register(helmet, {
    contentSecurityPolicy: false,
    crossOriginEmbedderPolicy: false
  });
  await app.register(rateLimit, {
    max: 120,
    timeWindow: "1 minute",
    keyGenerator: (request) => request.ip
  });

  const allowedOrigins = env.CORS_ORIGINS.split(",").map((value) => value.trim()).filter(Boolean);
  await app.register(cors, {
    origin: allowedOrigins.length ? allowedOrigins : false,
    credentials: false,
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
  });

  const authGuard = createAuthGuard(env);
  const pii = new PiiCipher(env.PII_ENCRYPTION_KEY_BASE64, env.PII_LOOKUP_KEY);

  await healthRoutes(app, db);
  await catalogRoutes(app, db);
  await favoriteRoutes(app, db, authGuard);
  await reservationRoutes(app, db, env, authGuard);
  await profileRoutes(app, db, pii, authGuard);

  app.setErrorHandler((error, request, reply) => {
    if (error instanceof HttpError) {
      return reply.status(error.statusCode).send({
        error: { code: error.code, message: error.message, request_id: request.id }
      });
    }
    request.log.error({ err: error }, "request failed");
    return reply.status(500).send({
      error: { code: "INTERNAL_ERROR", message: "Внутренняя ошибка сервера", request_id: request.id }
    });
  });

  app.setNotFoundHandler((request, reply) => reply.status(404).send({
    error: { code: "NOT_FOUND", message: "Маршрут не найден", request_id: request.id }
  }));

  return app;
}
