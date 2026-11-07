const path = require("path");
require("dotenv").config({
  path: path.join(__dirname, ".env"),
});

const { Pool } = require("pg");

const config = {
  host: String(process.env.DB_HOST || "127.0.0.1").trim(),
  port: Number(process.env.DB_PORT || 5432),
  database: String(process.env.DB_NAME || "library_db").trim(),
  user: String(process.env.DB_USER || "postgres").trim(),
  password: String(process.env.DB_PASSWORD || "").trim(),

  max: 10,
  min: 0,

  connectionTimeoutMillis: 20000,
  idleTimeoutMillis: 30000,

  keepAlive: true,
  keepAliveInitialDelayMillis: 10000,

  ssl: false,

  application_name: "library_management_system",
};

console.log("");
console.log("PostgreSQL configuration");
console.log("Host     :", config.host);
console.log("Port     :", config.port);
console.log("Database :", config.database);
console.log("User     :", config.user);
console.log("Password :", config.password ? "LOADED" : "NOT LOADED");
console.log("");

const pool = new Pool(config);

pool.on("connect", () => {
  console.log("PostgreSQL client connected");
});

pool.on("error", (error) => {
  console.error("Unexpected PostgreSQL pool error:", error.message);
});

async function testConnection(attempt = 1) {
  let client;

  try {
    console.log(`Testing PostgreSQL connection... attempt ${attempt}`);

    client = await pool.connect();

    const result = await client.query(`
      SELECT
        current_database() AS database,
        current_user AS db_user,
        NOW() AS server_time
    `);

    console.log("");
    console.log("==========================================");
    console.log("PostgreSQL CONNECTED SUCCESSFULLY");
    console.log("==========================================");
    console.log("Database :", result.rows[0].database);
    console.log("User     :", result.rows[0].db_user);
    console.log("DB Time  :", result.rows[0].server_time);
    console.log("==========================================");
    console.log("");

    return true;
  } catch (error) {
    console.error("");
    console.error("PostgreSQL connection attempt failed");
    console.error("Attempt  :", attempt);
    console.error("Message  :", error.message);
    console.error("Code     :", error.code || "N/A");
    console.error("");

    if (attempt < 5) {
      console.log("Retrying PostgreSQL connection in 2 seconds...");

      await new Promise((resolve) => setTimeout(resolve, 2000));

      return testConnection(attempt + 1);
    }

    console.error("PostgreSQL connection failed after 5 attempts.");
    return false;
  } finally {
    if (client) {
      client.release();
    }
  }
}

testConnection();

module.exports = pool;
