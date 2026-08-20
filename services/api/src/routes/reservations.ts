import type { FastifyInstance, FastifyRequest } from "fastify";
import { z } from "zod";
import type { Env } from "../config/env.js";
import type { Database } from "../db/pool.js";
import { parse } from "../lib/validation.js";
import { cancelReservation, createReservation } from "../services/reservations.js";

type AuthGuard = (request: FastifyRequest) => Promise<void>;

export async function reservationRoutes(app: FastifyInstance, db: Database, env: Env, authGuard: AuthGuard) {
  app.get("/api/v1/reservations", { preHandler: authGuard }, async (request) => {
    const { rows } = await db.query(`
      SELECT r.id, r.listing_id, r.store_id, r.quantity, r.unit_price_minor,
             r.status, r.created_at, r.expires_at,
             l.title, l.image_urls, s.name AS store_name, s.address AS store_address,
             s.phone_public
      FROM reservations r
      JOIN listings l ON l.id = r.listing_id
      JOIN stores s ON s.id = r.store_id
      WHERE r.user_id = $1
      ORDER BY r.created_at DESC
      LIMIT 100
    `, [request.authUser!.id]);
    return { items: rows };
  });

  app.post("/api/v1/reservations", { preHandler: authGuard }, async (request, reply) => {
    const body = parse(z.object({
      listing_id: z.string().uuid(),
      quantity: z.number().int().min(1).max(10).default(1)
    }), request.body);
    const reservation = await createReservation(db, {
      userId: request.authUser!.id,
      listingId: body.listing_id,
      quantity: body.quantity ?? 1,
      ttlMinutes: env.RESERVATION_TTL_MINUTES
    });
    return reply.code(201).send(reservation);
  });

  app.delete("/api/v1/reservations/:reservationId", { preHandler: authGuard }, async (request, reply) => {
    const { reservationId } = parse(z.object({ reservationId: z.string().uuid() }), request.params);
    await cancelReservation(db, reservationId, request.authUser!.id);
    return reply.code(204).send();
  });
}
