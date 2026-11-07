const express = require('express');
const pool = require('../db');
const authenticateToken = require('../middleware/auth');

const router = express.Router();

router.get('/', authenticateToken, async (req, res) => {
  try {
    const role = (req.user.role || '').toLowerCase();

    if (role === 'member') {
      const memberId = req.user.memberId;
      if (!memberId) {
        return res.json({
          total_titles: 0,
          total_copies: 0,
          available_copies: 0,
          total_members: 1,
          active_loans: 0,
          overdue_loans: 0,
        });
      }

      const result = await pool.query(
        `SELECT
          (SELECT COUNT(*) FROM books)::int AS total_titles,
          (SELECT COALESCE(SUM(total_copies),0) FROM books)::int AS total_copies,
          (SELECT COALESCE(SUM(available_copies),0) FROM books)::int AS available_copies,
          1::int AS total_members,
          (SELECT COUNT(*) FROM loans WHERE member_id=$1 AND status='Issued')::int AS active_loans,
          (SELECT COUNT(*) FROM loans WHERE member_id=$1 AND status='Issued' AND due_date::date<CURRENT_DATE)::int AS overdue_loans`,
        [memberId],
      );
      return res.json(result.rows[0]);
    }

    const result = await pool.query(`
      SELECT
        (SELECT COUNT(*) FROM books)::int AS total_titles,
        (SELECT COALESCE(SUM(total_copies),0) FROM books)::int AS total_copies,
        (SELECT COALESCE(SUM(available_copies),0) FROM books)::int AS available_copies,
        (SELECT COUNT(*) FROM members)::int AS total_members,
        (SELECT COUNT(*) FROM loans WHERE status='Issued')::int AS active_loans,
        (SELECT COUNT(*) FROM loans WHERE status='Issued' AND due_date::date<CURRENT_DATE)::int AS overdue_loans
    `);

    res.json(result.rows[0]);
  } catch (error) {
    console.error('Dashboard error:', error);
    res.status(500).json({ message: 'Failed to load dashboard' });
  }
});

module.exports = router;
