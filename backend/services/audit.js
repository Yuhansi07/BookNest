const pool = require('../db');

async function writeAudit({ userId = null, action, entityType = null, entityId = null, details = null }) {
  try {
    await pool.query(
      `INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details)
       VALUES ($1, $2, $3, $4, $5::jsonb)`,
      [userId, action, entityType, entityId, details ? JSON.stringify(details) : null],
    );
  } catch (error) {
    console.error('Audit write failed:', error.message);
  }
}

module.exports = writeAudit;
