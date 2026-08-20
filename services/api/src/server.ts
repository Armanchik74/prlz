import { buildApp } from "./app.js";
import { loadEnv } from "./config/env.js";
import { createPool } from "./db/pool.js";
import { expireReservations } from "./services/reservations.js";

const env = loadEnv();
const db = createPool(env.DATABASE_URL);
const app = await buildApp(env, db);

const expirationTimer = setInterval(() => {
  expireReservations(db).catch((error) => app.log.error({ err: error }, "reservation expiration failed"));
}, 60_000);
expirationTimer.unref();

async function shutdown(signal: string) {
  app.log.info({ signal }, "graceful shutdown");
  clearInterval(expirationTimer);
  await app.close();
  await db.end();
  process.exit(0);
}

process.once("SIGTERM", () => void shutdown("SIGTERM"));
process.once("SIGINT", () => void shutdown("SIGINT"));

try {
  await app.listen({ host: "0.0.0.0", port: env.PORT });
} catch (error) {
  app.log.fatal({ err: error }, "startup failed");
  await db.end();
  process.exit(1);
}
