const express = require('express');
const pool = require('../db');
const authenticateToken = require('../middleware/auth');
const allowRoles = require('../middleware/roles');

const router = express.Router();

router.get('/', authenticateToken, allowRoles('Admin'), async (req, res) => {
  try {
    const search = String(req.query.search || '').trim();
    const action = String(req.query.action || '').trim();
    const from = req.query.from || null;
    const to = req.query.to || null;

    const params = [];
    const conditions = [];
    if (search) {
      params.push(`%${search}%`);
      conditions.push(`(COALESCE(u.name,'') ILIKE $${params.length} OR COALESCE(u.email,'') ILIKE $${params.length} OR COALESCE(a.action,'') ILIKE $${params.length} OR COALESCE(a.entity_type,'') ILIKE $${params.length})`);
    }
    if (action) {
      params.push(action);
      conditions.push(`a.action=$${params.length}`);
    }
    if (from) {
      params.push(from);
      conditions.push(`a.created_at::date >= $${params.length}::date`);
    }
    if (to) {
      params.push(to);
      conditions.push(`a.created_at::date <= $${params.length}::date`);
    }

    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
    const result = await pool.query(
      `SELECT a.*, u.name AS user_name, u.email AS user_email
       FROM audit_logs a
       LEFT JOIN users u ON u.id=a.user_id
       ${where}
       ORDER BY a.created_at DESC
       LIMIT 500`,
      params,
    );
    res.json(result.rows);
  } catch (error) {
    console.error('Audit list error:', error);
    res.status(500).json({ message: 'Failed to load audit logs' });
  }
});

module.exports = router;
