const express = require('express');
const pool = require('../db');
const authenticateToken = require('../middleware/auth');
const allowRoles = require('../middleware/roles');
const writeAudit = require('../services/audit');

const router = express.Router();

const sortMap = {
  title_asc: 'b.title ASC',
  title_desc: 'b.title DESC',
  author_asc: 'b.author ASC',
  author_desc: 'b.author DESC',
  popular: 'borrow_count DESC, b.title ASC',
  available: 'b.available_copies DESC, b.title ASC',
  newest: 'b.id DESC',
};

router.get('/', authenticateToken, async (req, res) => {
  try {
    const search = String(req.query.search || '').trim();
    const category = String(req.query.category || '').trim();
    const author = String(req.query.author || '').trim();
    const availability = String(req.query.availability || '').trim().toLowerCase();
    const sort = sortMap[req.query.sort] || 'b.title ASC';

    const params = [];
    const conditions = [];

    if (search) {
      params.push(`%${search}%`);
      conditions.push(`(
        b.title ILIKE $${params.length}
        OR b.author ILIKE $${params.length}
        OR b.isbn ILIKE $${params.length}
        OR COALESCE(b.category, '') ILIKE $${params.length}
        OR COALESCE(b.publisher, '') ILIKE $${params.length}
      )`);
    }

    if (category) {
      params.push(category);
      conditions.push(`b.category = $${params.length}`);
    }

    if (author) {
      params.push(`%${author}%`);
      conditions.push(`b.author ILIKE $${params.length}`);
    }

    if (availability === 'available') {
      conditions.push('b.available_copies > 0');
    } else if (availability === 'unavailable') {
      conditions.push('b.available_copies <= 0');
    } else if (availability === 'low') {
      conditions.push('b.available_copies <= b.low_stock_threshold');
    }

    const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';

    const result = await pool.query(
      `SELECT
        b.*,
        COALESCE(lc.borrow_count, 0)::int AS borrow_count,
        COALESCE(rc.reservation_count, 0)::int AS reservation_count,
        (b.available_copies <= b.low_stock_threshold) AS low_stock
       FROM books b
       LEFT JOIN LATERAL (
         SELECT COUNT(*) AS borrow_count
         FROM loans l
         WHERE l.book_id = b.id
       ) lc ON TRUE
       LEFT JOIN LATERAL (
         SELECT COUNT(*) AS reservation_count
         FROM reservations r
         WHERE r.book_id = b.id AND r.status IN ('Pending', 'Ready')
       ) rc ON TRUE
       ${where}
       ORDER BY ${sort}`,
      params,
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Get books error:', error);
    res.status(500).json({ message: 'Failed to get books' });
  }
});

router.get('/:id/details', authenticateToken, async (req, res) => {
  try {
    const id = Number(req.params.id);

    const bookResult = await pool.query(
      `SELECT
        b.*,
        COUNT(DISTINCT l.id)::int AS borrow_count,
        COUNT(DISTINCT l.id) FILTER (WHERE l.status = 'Issued')::int AS active_loan_count,
        COUNT(DISTINCT r.id) FILTER (WHERE r.status IN ('Pending','Ready'))::int AS active_reservation_count
       FROM books b
       LEFT JOIN loans l ON l.book_id = b.id
       LEFT JOIN reservations r ON r.book_id = b.id
       WHERE b.id = $1
       GROUP BY b.id`,
      [id],
    );

    if (bookResult.rows.length === 0) {
      return res.status(404).json({ message: 'Book not found' });
    }

    const recentLoans = await pool.query(
      `SELECT l.id, l.issue_date, l.due_date, l.return_date, l.status, l.fine,
              m.member_code, m.name AS member_name
       FROM loans l
       JOIN members m ON m.id = l.member_id
       WHERE l.book_id = $1
       ORDER BY l.issue_date DESC
       LIMIT 10`,
      [id],
    );

    res.json({
      book: bookResult.rows[0],
      recentLoans: recentLoans.rows,
    });
  } catch (error) {
    console.error('Book details error:', error);
    res.status(500).json({ message: 'Failed to get book details' });
  }
});

router.post('/', authenticateToken, allowRoles('Admin', 'Librarian'), async (req, res) => {
  try {
    const {
      isbn,
      title,
      author,
      category,
      publisher,
      totalCopies,
      coverUrl,
      shelfLocation,
      description,
      lowStockThreshold,
    } = req.body;

    if (!isbn || !title || !author) {
      return res.status(400).json({ message: 'ISBN, title and author are required' });
    }

    const copies = Math.max(1, Number(totalCopies) || 1);

    const result = await pool.query(
      `INSERT INTO books
       (isbn, title, author, category, publisher, total_copies, available_copies,
        cover_url, shelf_location, description, low_stock_threshold)
       VALUES ($1,$2,$3,$4,$5,$6,$6,$7,$8,$9,$10)
       RETURNING *`,
      [
        isbn.trim(),
        title.trim(),
        author.trim(),
        category?.trim() || null,
        publisher?.trim() || null,
        copies,
        coverUrl?.trim() || null,
        shelfLocation?.trim() || null,
        description?.trim() || null,
        Math.max(0, Number(lowStockThreshold) || 1),
      ],
    );

    await writeAudit({
      userId: req.user.id,
      action: 'BOOK_CREATED',
      entityType: 'Book',
      entityId: result.rows[0].id,
      details: { title, isbn },
    });

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Create book error:', error);
    if (error.code === '23505') {
      return res.status(409).json({ message: 'ISBN already exists' });
    }
    res.status(500).json({ message: 'Failed to create book' });
  }
});

router.put('/:id', authenticateToken, allowRoles('Admin', 'Librarian'), async (req, res) => {
  const client = await pool.connect();
  try {
    const id = Number(req.params.id);
    const {
      isbn,
      title,
      author,
      category,
      publisher,
      totalCopies,
      coverUrl,
      shelfLocation,
      description,
      lowStockThreshold,
    } = req.body;

    await client.query('BEGIN');

    const currentResult = await client.query('SELECT * FROM books WHERE id=$1 FOR UPDATE', [id]);
    if (currentResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ message: 'Book not found' });
    }

    const current = currentResult.rows[0];
    const newTotal = Math.max(1, Number(totalCopies) || current.total_copies);
    const borrowed = Number(current.total_copies) - Number(current.available_copies);

    if (newTotal < borrowed) {
      await client.query('ROLLBACK');
      return res.status(400).json({
        message: `Total copies cannot be below currently borrowed copies (${borrowed})`,
      });
    }

    const newAvailable = newTotal - borrowed;

    const result = await client.query(
      `UPDATE books
       SET isbn=$1, title=$2, author=$3, category=$4, publisher=$5,
           total_copies=$6, available_copies=$7, cover_url=$8,
           shelf_location=$9, description=$10, low_stock_threshold=$11,
           updated_at=CURRENT_TIMESTAMP
       WHERE id=$12
       RETURNING *`,
      [
        isbn?.trim() || current.isbn,
        title?.trim() || current.title,
        author?.trim() || current.author,
        category?.trim() || null,
        publisher?.trim() || null,
        newTotal,
        newAvailable,
        coverUrl?.trim() || null,
        shelfLocation?.trim() || null,
        description?.trim() || null,
        Math.max(0, Number(lowStockThreshold) || 1),
        id,
      ],
    );

    await client.query('COMMIT');

    await writeAudit({
      userId: req.user.id,
      action: 'BOOK_UPDATED',
      entityType: 'Book',
      entityId: id,
      details: { title: result.rows[0].title },
    });

    res.json(result.rows[0]);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Update book error:', error);
    res.status(500).json({ message: 'Failed to update book' });
  } finally {
    client.release();
  }
});

router.delete('/:id', authenticateToken, allowRoles('Admin'), async (req, res) => {
  try {
    const id = Number(req.params.id);

    const active = await pool.query(
      `SELECT COUNT(*)::int AS count FROM loans WHERE book_id=$1 AND status='Issued'`,
      [id],
    );

    if (active.rows[0].count > 0) {
      return res.status(400).json({ message: 'Cannot delete a book with active loans' });
    }

    const result = await pool.query('DELETE FROM books WHERE id=$1 RETURNING id, title', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ message: 'Book not found' });
    }

    await writeAudit({
      userId: req.user.id,
      action: 'BOOK_DELETED',
      entityType: 'Book',
      entityId: id,
      details: { title: result.rows[0].title },
    });

    res.json({ message: 'Book deleted successfully' });
  } catch (error) {
    console.error('Delete book error:', error);
    res.status(500).json({ message: 'Failed to delete book' });
  }
});

module.exports = router;
