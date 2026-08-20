import type { FastifyInstance } from "fastify";
import type { Database } from "../db/pool.js";

export async function healthRoutes(app: FastifyInstance, db: Database) {
  app.get("/health", async (_request, reply) => {
    await db.query("SELECT 1");
    return reply.send({ status: "ok", service: "city-marketplace-api" });
  });
}
