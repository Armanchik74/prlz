import pg from "pg";

const { Pool } = pg;
pg.types.setTypeParser(20, (value) => Number(value));
pg.types.setTypeParser(1700, (value) => Number(value));

export function createPool(connectionString: string) {
  return new Pool({
    connectionString,
    max: 20,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 5_000,
    statement_timeout: 5_000,
    application_name: "city-marketplace-api"
  });
}

export type Database = ReturnType<typeof createPool>;
