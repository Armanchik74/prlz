import type { Database } from "../db/pool.js";
import { conflict, notFound } from "../lib/errors.js";

export async function createReservation(db: Database, input: {
  userId: string;
  listingId: string;
  quantity: number;
  ttlMinutes: number;
}) {
  const client = await db.connect();
  try {
    await client.query("BEGIN");
    const listingResult = await client.query(`
      SELECT id, store_id, price_minor, stock, reserved_stock
      FROM listings WHERE id = $1 AND status = 'active' FOR UPDATE
    `, [input.listingId]);
    const listing = listingResult.rows[0];
    if (!listing) throw notFound("Товар не найден");
    if (listing.stock - listing.reserved_stock < input.quantity) {
      throw conflict("Недостаточно товара для бронирования");
    }

    const created = await client.query(`
      INSERT INTO reservations(user_id, store_id, listing_id, quantity, unit_price_minor, expires_at)
      VALUES($1, $2, $3, $4, $5, now() + make_interval(mins => $6))
      RETURNING id, listing_id, store_id, quantity, unit_price_minor, status, created_at, expires_at
    `, [input.userId, listing.store_id, input.listingId, input.quantity, listing.price_minor, input.ttlMinutes]);
    await client.query(
      "UPDATE listings SET reserved_stock = reserved_stock + $2, updated_at = now() WHERE id = $1",
      [input.listingId, input.quantity]
    );
    await client.query(
      "INSERT INTO audit_events(actor_user_id, event_type, entity_type, entity_id) VALUES($1, 'reservation.created', 'reservation', $2)",
      [input.userId, created.rows[0].id]
    );
    await client.query("COMMIT");
    return created.rows[0];
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

export async function cancelReservation(db: Database, reservationId: string, userId: string) {
  const client = await db.connect();
  try {
    await client.query("BEGIN");
    const result = await client.query(`
      UPDATE reservations SET status = 'cancelled', updated_at = now()
      WHERE id = $1 AND user_id = $2 AND status IN ('pending', 'confirmed')
      RETURNING listing_id, quantity
    `, [reservationId, userId]);
    const reservation = result.rows[0];
    if (!reservation) throw notFound("Активная бронь не найдена");
    await client.query(`
      UPDATE listings SET reserved_stock = GREATEST(reserved_stock - $2, 0), updated_at = now()
      WHERE id = $1
    `, [reservation.listing_id, reservation.quantity]);
    await client.query(
      "INSERT INTO audit_events(actor_user_id, event_type, entity_type, entity_id) VALUES($1, 'reservation.cancelled', 'reservation', $2)",
      [userId, reservationId]
    );
    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
  }
}

export async function expireReservations(db: Database) {
  await db.query(`
    WITH expired AS (
      UPDATE reservations SET status = 'expired', updated_at = now()
      WHERE status IN ('pending', 'confirmed') AND expires_at <= now()
      RETURNING listing_id, quantity
    ), totals AS (
      SELECT listing_id, SUM(quantity)::integer AS quantity FROM expired GROUP BY listing_id
    )
    UPDATE listings l
    SET reserved_stock = GREATEST(l.reserved_stock - totals.quantity, 0), updated_at = now()
    FROM totals WHERE l.id = totals.listing_id
  `);
}
