const express = require('express');
const pool = require('../db');
const authenticateToken = require('../middleware/auth');
const allowRoles = require('../middleware/roles');
const writeAudit = require('../services/audit');

const router = express.Router();

async function expireOldReservations(client = pool) {
  const expired = await client.query(
    `UPDATE reservations
     SET status='Expired', updated_at=CURRENT_TIMESTAMP
     WHERE status IN ('Pending','Ready')
       AND expiry_date IS NOT NULL
       AND expiry_date < CURRENT_TIMESTAMP
     RETURNING id, member_id, book_id`,
  );

  for (const row of expired.rows) {
    await client.query(
      `INSERT INTO notifications (member_id, title, message, type)
       VALUES ($1,'Reservation expired','A reservation expired before pickup.','Reservation')`,
      [row.member_id],
    );
  }
}

router.get('/', authenticateToken, async (req, res) => {
  try {
    await expireOldReservations();

    const params = [];
    let outerFilter = '';
    if ((req.user.role || '').toLowerCase() === 'member') {
      if (!req.user.memberId) return res.json([]);
      params.push(req.user.memberId);
      outerFilter = 'WHERE x.member_id=$1';
    }

    const result = await pool.query(
      `SELECT * FROM (
        SELECT
          r.id, r.book_id, b.title AS book_title, b.isbn,
          r.member_id, m.member_code, m.name AS member_name,
          r.reservation_date, r.expiry_date, r.ready_at, r.completed_at,
          r.status, r.notes,
          CASE
            WHEN r.status='Pending' THEN
              SUM(CASE WHEN r.status='Pending' THEN 1 ELSE 0 END) OVER (
                PARTITION BY r.book_id
                ORDER BY r.reservation_date
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
              )::int
            ELSE NULL
          END AS queue_position
        FROM reservations r
        JOIN books b ON b.id=r.book_id
        JOIN members m ON m.id=r.member_id
      ) x
      ${outerFilter}
      ORDER BY
        CASE x.status WHEN 'Ready' THEN 0 WHEN 'Pending' THEN 1 ELSE 2 END,
        x.reservation_date DESC`,
      params,
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Get reservations error:', error);
    res.status(500).json({ message: 'Failed to get reservations' });
  }
});

router.post('/', authenticateToken, async (req, res) => {
  try {
    let { bookId, memberId } = req.body;

    if ((req.user.role || '').toLowerCase() === 'member') {
      memberId = req.user.memberId;
    }

    if (!bookId || !memberId) return res.status(400).json({ message: 'Book and member are required' });

    const member = await pool.query('SELECT id, status FROM members WHERE id=$1', [memberId]);
    if (!member.rows[0]) return res.status(404).json({ message: 'Member not found' });
    if (member.rows[0].status !== 'Active') return res.status(400).json({ message: 'Member is not active' });

    const duplicate = await pool.query(
      `SELECT id FROM reservations
       WHERE book_id=$1 AND member_id=$2 AND status IN ('Pending','Ready')`,
      [bookId, memberId],
    );
    if (duplicate.rows.length > 0) return res.status(400).json({ message: 'Active reservation already exists' });

    const result = await pool.query(
      `INSERT INTO reservations
       (book_id, member_id, reservation_date, expiry_date, status)
       VALUES ($1,$2,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP + INTERVAL '7 days','Pending')
       RETURNING *`,
      [bookId, memberId],
    );

    await writeAudit({ userId: req.user.id, action: 'RESERVATION_CREATED', entityType: 'Reservation', entityId: result.rows[0].id, details: { bookId, memberId } });
    res.status(201).json({ message: 'Reservation created', reservation: result.rows[0] });
  } catch (error) {
    console.error('Create reservation error:', error);
    res.status(500).json({ message: 'Failed to create reservation' });
  }
});

router.put('/:id/cancel', authenticateToken, async (req, res) => {
  try {
    const id = Number(req.params.id);
    const params = [id];
    let ownerFilter = '';
    if ((req.user.role || '').toLowerCase() === 'member') {
      params.push(req.user.memberId || -1);
      ownerFilter = 'AND member_id=$2';
    }

    const result = await pool.query(
      `UPDATE reservations
       SET status='Cancelled', updated_at=CURRENT_TIMESTAMP
       WHERE id=$1 ${ownerFilter} AND status IN ('Pending','Ready')
       RETURNING *`,
      params,
    );
    if (!result.rows[0]) return res.status(404).json({ message: 'Active reservation not found' });

    await writeAudit({ userId: req.user.id, action: 'RESERVATION_CANCELLED', entityType: 'Reservation', entityId: id });
    res.json({ message: 'Reservation cancelled', reservation: result.rows[0] });
  } catch (error) {
    console.error('Cancel reservation error:', error);
    res.status(500).json({ message: 'Failed to cancel reservation' });
  }
});

router.put('/:id/ready', authenticateToken, allowRoles('Admin', 'Librarian'), async (req, res) => {
  try {
    const id = Number(req.params.id);
    const result = await pool.query(
      `UPDATE reservations
       SET status='Ready', ready_at=CURRENT_TIMESTAMP,
           expiry_date=CURRENT_TIMESTAMP + INTERVAL '3 days', updated_at=CURRENT_TIMESTAMP
       WHERE id=$1 AND status='Pending'
       RETURNING *`,
      [id],
    );
    if (!result.rows[0]) return res.status(400).json({ message: 'Pending reservation not found' });

    await pool.query(
      `INSERT INTO notifications (member_id, title, message, type)
       VALUES ($1,'Book ready for pickup','Your reserved book is ready. Please collect it before the expiry date.','Reservation')`,
      [result.rows[0].member_id],
    );

    await writeAudit({ userId: req.user.id, action: 'RESERVATION_READY', entityType: 'Reservation', entityId: id });
    res.json({ message: 'Reservation marked ready', reservation: result.rows[0] });
  } catch (error) {
    console.error('Ready reservation error:', error);
    res.status(500).json({ message: 'Failed to mark reservation ready' });
  }
});

router.post('/:id/convert-to-loan', authenticateToken, allowRoles('Admin', 'Librarian'), async (req, res) => {
  const client = await pool.connect();
  try {
    const id = Number(req.params.id);
    const dueDate = req.body.dueDate;
    if (!dueDate) return res.status(400).json({ message: 'Due date is required' });

    await client.query('BEGIN');
    const reservationResult = await client.query(
      `SELECT * FROM reservations WHERE id=$1 FOR UPDATE`,
      [id],
    );
    if (!reservationResult.rows[0]) {
      await client.query('ROLLBACK');
      return res.status(404).json({ message: 'Reservation not found' });
    }

    const reservation = reservationResult.rows[0];
    if (!['Pending','Ready'].includes(reservation.status)) {
      await client.query('ROLLBACK');
      return res.status(400).json({ message: 'Reservation is not active' });
    }

    const book = await client.query('SELECT * FROM books WHERE id=$1 FOR UPDATE', [reservation.book_id]);
    if (!book.rows[0] || Number(book.rows[0].available_copies) <= 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ message: 'No available copy to issue' });
    }

    const duplicate = await client.query(
      `SELECT id FROM loans WHERE book_id=$1 AND member_id=$2 AND status='Issued'`,
      [reservation.book_id, reservation.member_id],
    );
    if (duplicate.rows.length > 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ message: 'Member already has this book issued' });
    }

    const loan = await client.query(
      `INSERT INTO loans (book_id, member_id, due_date, status, fine, fine_paid)
       VALUES ($1,$2,$3,'Issued',0,false)
       RETURNING *`,
      [reservation.book_id, reservation.member_id, dueDate],
    );

    await client.query('UPDATE books SET available_copies=available_copies-1 WHERE id=$1', [reservation.book_id]);
    await client.query(
      `UPDATE reservations SET status='Completed', completed_at=CURRENT_TIMESTAMP, updated_at=CURRENT_TIMESTAMP WHERE id=$1`,
      [id],
    );
    await client.query('COMMIT');

    await writeAudit({ userId: req.user.id, action: 'RESERVATION_CONVERTED_TO_LOAN', entityType: 'Loan', entityId: loan.rows[0].id, details: { reservationId: id } });
    res.json({ message: 'Reservation converted to loan', loan: loan.rows[0] });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Convert reservation error:', error);
    res.status(500).json({ message: 'Failed to convert reservation' });
  } finally {
    client.release();
  }
});

router.post('/expire-stale/run', authenticateToken, allowRoles('Admin', 'Librarian'), async (req, res) => {
  try {
    await expireOldReservations();
    res.json({ message: 'Expired reservations updated' });
  } catch (error) {
    console.error('Expire reservations error:', error);
    res.status(500).json({ message: 'Failed to expire reservations' });
  }
});

module.exports = router;
