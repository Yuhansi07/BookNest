const express = require('express');
const pool = require('../db');
const authenticateToken = require('../middleware/auth');

const router = express.Router();

router.get('/', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT COALESCE(NULLIF(category,''),'Uncategorized') AS category,
             COUNT(*)::int AS book_count,
             COALESCE(SUM(total_copies),0)::int AS total_copies,
             COALESCE(SUM(available_copies),0)::int AS available_copies
      FROM books
      GROUP BY COALESCE(NULLIF(category,''),'Uncategorized')
      ORDER BY category
    `);
    res.json(result.rows);
  } catch (error) {
    console.error('Categories error:', error);
    res.status(500).json({ message: 'Failed to load categories' });
  }
});

module.exports = router;
