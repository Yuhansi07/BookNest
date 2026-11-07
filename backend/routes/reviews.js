
const express = require('express');
const pool = require('../db');
const authenticateToken = require('../middleware/auth');
const router = express.Router();

let ready;

async function ensureTable() {
  if (!ready) {
    ready = pool.query(`
      CREATE TABLE IF NOT EXISTS book_reviews (
        id SERIAL PRIMARY KEY,
        book_id INTEGER NOT NULL
          REFERENCES books(id) ON DELETE CASCADE,
        member_id INTEGER NOT NULL
          REFERENCES members(id) ON DELETE CASCADE,
        rating SMALLINT NOT NULL
          CHECK (rating BETWEEN 1 AND 5),
        comment VARCHAR(500) NOT NULL DEFAULT '',
        created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (book_id, member_id)
      )
    `).catch(error => {
      ready = null;
      throw error;
    });
  }

  await ready;
}

router.get('/', authenticateToken, async (req, res) => {
  try {
    await ensureTable();

    const result = await pool.query(`
      SELECT
        book_id,
        ROUND(AVG(rating)::numeric, 2)::float8 AS average_rating,
        COUNT(*)::int AS rating_count
      FROM book_reviews
      GROUP BY book_id
    `);

    res.json(result.rows);
  } catch (error) {
    console.error('Review summaries error:', error);
    res.status(500).json({
      message: 'Unable to load reviews'
    });
  }
});

router.post('/', authenticateToken, async (req, res) => {
  try {
    const role = String(req.user?.role || '').toLowerCase();

    if (role !== 'member') {
      return res.status(403).json({
        message: 'Member account required'
      });
    }

    const memberId = Number(
      req.user?.memberId ?? req.user?.member_id
    );

    const bookId = Number(req.body?.bookId);
    const rating = Number(req.body?.rating);
    const comment = String(req.body?.comment || '').trim();

    if (
      !Number.isInteger(memberId) || memberId < 1 ||
      !Number.isInteger(bookId) || bookId < 1 ||
      !Number.isInteger(rating) ||
      rating < 1 || rating > 5 ||
      comment.length > 500
    ) {
      return res.status(400).json({
        message: 'Invalid review details'
      });
    }

    // Only members who actually returned this book can review it.
    const proof = await pool.query(
      `SELECT id FROM loans
       WHERE book_id=$1
         AND member_id=$2
         AND status='Returned'
       LIMIT 1`,
      [bookId, memberId]
    );

    if (!proof.rows.length) {
      return res.status(403).json({
        message: 'You can review a book only after returning it'
      });
    }

    await ensureTable();

    const result = await pool.query(`
      INSERT INTO book_reviews
        (book_id, member_id, rating, comment)
      VALUES ($1, $2, $3, $4)

      ON CONFLICT (book_id, member_id)
      DO UPDATE SET
        rating = EXCLUDED.rating,
        comment = EXCLUDED.comment,
        updated_at = CURRENT_TIMESTAMP

      RETURNING id, book_id, rating, comment, updated_at
    `, [bookId, memberId, rating, comment]);

    return res.json({
      message: 'Thank you! Your book review was saved.',
      review: result.rows[0]
    });

  } catch (error) {
    console.error('Save review error:', error);

    return res.status(500).json({
      message: 'Unable to save review'
    });
  }
});

module.exports = router;
