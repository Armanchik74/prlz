import type { FastifyInstance, FastifyRequest } from "fastify";
import { z } from "zod";
import type { Database } from "../db/pool.js";
import { notFound } from "../lib/errors.js";
import type { PiiCipher } from "../lib/pii.js";
import { parse } from "../lib/validation.js";

type AuthGuard = (request: FastifyRequest) => Promise<void>;

const profileSchema = z.object({
  name: z.string().trim().min(1).max(100),
  phone: z.string().trim().regex(/^\+7\d{10}$/)
});

export async function profileRoutes(app: FastifyInstance, db: Database, pii: PiiCipher, authGuard: AuthGuard) {
  app.get("/api/v1/me", { preHandler: authGuard }, async (request) => {
    const { rows } = await db.query(
      "SELECT id, role, name_encrypted, phone_encrypted, consent_version, created_at FROM users WHERE id = $1 AND deleted_at IS NULL",
      [request.authUser!.id]
    );
    const user = rows[0];
    if (!user) throw notFound("Профиль не найден");
    return {
      id: user.id,
      role: user.role,
      name: pii.decrypt(user.name_encrypted),
      phone: pii.decrypt(user.phone_encrypted),
      consent_version: user.consent_version,
      created_at: user.created_at
    };
  });

  app.put("/api/v1/me", { preHandler: authGuard }, async (request) => {
    const body = parse(profileSchema, request.body);
    const { rows } = await db.query(`
      UPDATE users
      SET name_encrypted = $2, phone_encrypted = $3, phone_lookup_hash = $4, updated_at = now()
      WHERE id = $1 AND deleted_at IS NULL
      RETURNING id, role, consent_version, created_at
    `, [
      request.authUser!.id,
      pii.encrypt(body.name),
      pii.encrypt(body.phone),
      pii.lookupHash(body.phone)
    ]);
    if (!rows[0]) throw notFound("Профиль не найден");
    await db.query(
      "INSERT INTO audit_events(actor_user_id, event_type, entity_type, entity_id) VALUES($1, 'profile.updated', 'user', $1)",
      [request.authUser!.id]
    );
    return { ...rows[0], name: body.name, phone: body.phone };
  });

  app.delete("/api/v1/me", { preHandler: authGuard }, async (request, reply) => {
    await db.query(`
      UPDATE users
      SET deleted_at = now(), name_encrypted = NULL, phone_encrypted = NULL,
          phone_lookup_hash = NULL, updated_at = now()
      WHERE id = $1
    `, [request.authUser!.id]);
    await db.query(
      "INSERT INTO audit_events(actor_user_id, event_type, entity_type, entity_id) VALUES($1, 'profile.deleted', 'user', $1)",
      [request.authUser!.id]
    );
    return reply.code(204).send();
  });
}
