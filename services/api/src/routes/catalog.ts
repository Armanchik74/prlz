import type { FastifyInstance } from "fastify";
import { z } from "zod";
import type { Database } from "../db/pool.js";
import { notFound } from "../lib/errors.js";
import { parse } from "../lib/validation.js";

const locationQuery = z.object({
  category: z.string().uuid().optional(),
  lat: z.coerce.number().min(-90).max(90).optional(),
  lon: z.coerce.number().min(-180).max(180).optional()
}).refine((value) => (value.lat == null) === (value.lon == null));

const searchQuery = z.object({
  q: z.string().trim().min(2).max(120),
  category: z.string().uuid().optional(),
  lat: z.coerce.number().min(-90).max(90).optional(),
  lon: z.coerce.number().min(-180).max(180).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(30)
}).refine((value) => (value.lat == null) === (value.lon == null));

export async function catalogRoutes(app: FastifyInstance, db: Database) {
  app.get("/api/v1/categories", async () => {
    const { rows } = await db.query(`
      SELECT c.id, c.slug, c.name, c.icon, c.color,
             COALESCE(json_agg(json_build_object('id', sc.id, 'slug', sc.slug, 'name', sc.name)
               ORDER BY sc.sort_order) FILTER (WHERE sc.id IS NOT NULL), '[]') AS subcategories
      FROM categories c
      LEFT JOIN subcategories sc ON sc.category_id = c.id AND sc.is_active
      WHERE c.is_active
      GROUP BY c.id
      ORDER BY c.sort_order
    `);
    return { items: rows };
  });

  app.get("/api/v1/stores", async (request) => {
    const query = parse(locationQuery, request.query);
    const hasLocation = query.lat != null && query.lon != null;
    const { rows } = await db.query(`
      SELECT s.id, s.name, s.description, s.address, s.phone_public, s.rating,
             s.review_count, s.opening_hours, s.is_verified, s.plan,
             ST_Y(s.location::geometry) AS latitude,
             ST_X(s.location::geometry) AS longitude,
             CASE WHEN $1::double precision IS NULL THEN NULL ELSE
               ROUND((ST_DistanceSphere(s.location::geometry,
                 ST_SetSRID(ST_MakePoint($2, $1), 4326)) / 1000)::numeric, 1)
             END AS distance_km
      FROM stores s
      WHERE s.status = 'active'
        AND ($3::uuid IS NULL OR s.category_id = $3)
      ORDER BY CASE s.plan WHEN 'business' THEN 0 WHEN 'standard' THEN 1 ELSE 2 END,
               ${hasLocation ? "distance_km NULLS LAST," : ""} s.rating DESC
      LIMIT 100
    `, [query.lat ?? null, query.lon ?? null, query.category ?? null]);
    return { items: rows };
  });

  app.get("/api/v1/stores/:storeId", async (request) => {
    const { storeId } = parse(z.object({ storeId: z.string().uuid() }), request.params);
    const storeResult = await db.query(`
      SELECT s.id, s.name, s.description, s.address, s.phone_public, s.rating,
             s.review_count, s.opening_hours, s.is_verified, s.plan,
             ST_Y(s.location::geometry) AS latitude, ST_X(s.location::geometry) AS longitude
      FROM stores s WHERE s.id = $1 AND s.status = 'active'
    `, [storeId]);
    const store = storeResult.rows[0];
    if (!store) throw notFound("Магазин не найден");

    const listings = await db.query(`
      SELECT l.id, l.title, l.description, l.price_minor, l.currency, l.stock,
             l.reserved_stock, GREATEST(l.stock - l.reserved_stock, 0) AS available_stock,
             l.condition, l.tags, l.image_urls
      FROM listings l WHERE l.store_id = $1 AND l.status = 'active'
      ORDER BY l.title
    `, [storeId]);
    return { ...store, listings: listings.rows };
  });

  app.get("/api/v1/listings/search", async (request) => {
    const query = parse(searchQuery, request.query);
    const { rows } = await db.query(`
      SELECT l.id, l.title, l.description, l.price_minor, l.currency,
             GREATEST(l.stock - l.reserved_stock, 0) AS available_stock,
             l.condition, l.tags, l.image_urls,
             s.id AS store_id, s.name AS store_name, s.address AS store_address,
             s.rating AS store_rating, s.is_verified, s.plan,
             c.id AS category_id, c.name AS category_name, c.icon AS category_icon,
             CASE WHEN $3::double precision IS NULL THEN NULL ELSE
               ROUND((ST_DistanceSphere(s.location::geometry,
                 ST_SetSRID(ST_MakePoint($4, $3), 4326)) / 1000)::numeric, 1)
             END AS distance_km
      FROM listings l
      JOIN stores s ON s.id = l.store_id AND s.status = 'active'
      JOIN categories c ON c.id = l.category_id
      WHERE l.status = 'active'
        AND l.search_document @@ websearch_to_tsquery('russian', $1)
        AND ($2::uuid IS NULL OR l.category_id = $2)
      ORDER BY ts_rank(l.search_document, websearch_to_tsquery('russian', $1)) DESC,
               l.price_minor ASC
      LIMIT $5
    `, [query.q, query.category ?? null, query.lat ?? null, query.lon ?? null, query.limit]);
    return { query: query.q, items: rows };
  });

  app.get("/api/v1/listings/:listingId", async (request) => {
    const { listingId } = parse(z.object({ listingId: z.string().uuid() }), request.params);
    const { rows } = await db.query(`
      SELECT l.id, l.title, l.description, l.price_minor, l.currency,
             GREATEST(l.stock - l.reserved_stock, 0) AS available_stock,
             l.condition, l.tags, l.image_urls,
             s.id AS store_id, s.name AS store_name, s.address AS store_address,
             s.phone_public, s.rating AS store_rating, s.is_verified, s.plan,
             ST_Y(s.location::geometry) AS latitude, ST_X(s.location::geometry) AS longitude
      FROM listings l JOIN stores s ON s.id = l.store_id
      WHERE l.id = $1 AND l.status = 'active' AND s.status = 'active'
    `, [listingId]);
    if (!rows[0]) throw notFound("Товар не найден");
    return rows[0];
  });
}
