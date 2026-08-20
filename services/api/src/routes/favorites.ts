import type { FastifyInstance, FastifyRequest } from "fastify";
import { z } from "zod";
import type { Database } from "../db/pool.js";
import { parse } from "../lib/validation.js";

type AuthGuard = (request: FastifyRequest) => Promise<void>;

export async function favoriteRoutes(app: FastifyInstance, db: Database, authGuard: AuthGuard) {
  app.get("/api/v1/favorites", { preHandler: authGuard }, async (request) => {
    const { rows } = await db.query(`
      SELECT l.id, l.title, l.description, l.price_minor, l.currency,
             GREATEST(l.stock - l.reserved_stock, 0) AS available_stock,
             l.condition, l.tags, l.image_urls,
             s.id AS store_id, s.name AS store_name, s.address AS store_address,
             s.rating AS store_rating, s.is_verified, s.plan
      FROM favorites f
      JOIN listings l ON l.id = f.listing_id AND l.status = 'active'
      JOIN stores s ON s.id = l.store_id AND s.status = 'active'
      WHERE f.user_id = $1 ORDER BY f.created_at DESC
    `, [request.authUser!.id]);
    return { items: rows };
  });

  app.put("/api/v1/favorites/:listingId", { preHandler: authGuard }, async (request, reply) => {
    const { listingId } = parse(z.object({ listingId: z.string().uuid() }), request.params);
    await db.query("INSERT INTO favorites(user_id, listing_id) VALUES($1, $2) ON CONFLICT DO NOTHING", [request.authUser!.id, listingId]);
    await db.query(
      "INSERT INTO audit_events(actor_user_id, event_type, entity_type, entity_id) VALUES($1, 'favorite.added', 'listing', $2)",
      [request.authUser!.id, listingId]
    );
    return reply.code(204).send();
  });

  app.delete("/api/v1/favorites/:listingId", { preHandler: authGuard }, async (request, reply) => {
    const { listingId } = parse(z.object({ listingId: z.string().uuid() }), request.params);
    await db.query("DELETE FROM favorites WHERE user_id = $1 AND listing_id = $2", [request.authUser!.id, listingId]);
    await db.query(
      "INSERT INTO audit_events(actor_user_id, event_type, entity_type, entity_id) VALUES($1, 'favorite.removed', 'listing', $2)",
      [request.authUser!.id, listingId]
    );
    return reply.code(204).send();
  });
}
