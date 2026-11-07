const express = require('express');
const pool = require('../db');
const authenticateToken = require('../middleware/auth');
const allowRoles = require('../middleware/roles');
const writeAudit = require('../services/audit');

const router = express.Router();
const finePerDay = () => Number(process.env.FINE_PER_DAY) || 50;

router.get('/', authenticateToken, async (req, res) => {
  try {
    const params = [];
    let memberFilter = '';

    if ((req.user.role || '').toLowerCase() === 'member') {
      if (!req.user.memberId) return res.json([]);
      params.push(req.user.memberId);
      memberFilter = `WHERE l.member_id=$1`;
    }

    const result = await pool.query(
      `SELECT
        l.id, l.book_id, b.title AS book_title, b.isbn,
        l.member_id, m.member_code, m.name AS member_name,
        l.issue_date, l.due_date, l.return_date, l.status,
        l.fine, COALESCE(l.fine_paid,false) AS fine_paid, l.fine_paid_at,
        COALESCE(l.renew_count,0) AS renew_count, l.last_renewed_at,
        CASE
          WHEN l.status='Issued' AND l.due_date::date < CURRENT_DATE THEN 'Overdue'
          ELSE l.status
        END AS display_status,
        CASE
          WHEN l.status='Issued' THEN (l.due_date::date - CURRENT_DATE)
          ELSE NULL
        END AS days_remaining,
        CASE
          WHEN l.status='Issued' AND l.due_date::date < CURRENT_DATE
            THEN (CURRENT_DATE - l.due_date::date) * $${params.length + 1}::numeric
          ELSE COALESCE(l.fine,0)
        END AS calculated_fine
       FROM loans l
       JOIN books b ON b.id=l.book_id
       JOIN members m ON m.id=l.member_id
       ${memberFilter}
       ORDER BY l.id DESC`,
      [...params, finePerDay()],
    );

    res.json(result.rows);
  } catch (error) {
    console.error('Get loans error:', error);
    res.status(500).json({ message: 'Failed to get loans' });
  }
});


// LMS_RETURN_REVIEW_V1
async function sendReturnMessages(client, loan) {
  const result = await client.query(
    'SELECT title FROM books WHERE id=$1',
    [loan.book_id]
  );

  const bookTitle = result.rows[0]?.title || 'the book';

  await client.query(
    `INSERT INTO notifications (member_id, title, message, type)
     VALUES
       ($1, 'Book return confirmed', $2, 'Loan'),
       ($1, 'Rate your returned book', $3, $4)`,
    [
      loan.member_id,
      `Your return of "${bookTitle}" has been confirmed by the library. Thank you!`,
      `You have returned "${bookTitle}". Please rate it from 1 to 5 stars and optionally write a review.`,
      `Review:${loan.book_id}`,
    ]
  );
}

async function issueBook(client, { bookId, memberId, dueDate }) {
  const bookResult = await client.query(
    `SELECT id, title, available_copies FROM books WHERE id=$1 FOR UPDATE`,
    [bookId],
  );
  if (bookResult.rows.length === 0) throw Object.assign(new Error('Book not found'), { status: 404 });
  if (Number(bookResult.rows[0].available_copies) <= 0) throw Object.assign(new Error('Book is currently unavailable'), { status: 400 });

  const memberResult = await client.query(
    `SELECT id, name, status, membership_expiry FROM members WHERE id=$1`,
    [memberId],
  );
  if (memberResult.rows.length === 0) throw Object.assign(new Error('Member not found'), { status: 404 });
  if (memberResult.rows[0].status !== 'Active') throw Object.assign(new Error('Member is not active'), { status: 400 });
  if (memberResult.rows[0].membership_expiry && new Date(memberResult.rows[0].membership_expiry) < new Date()) {
    throw Object.assign(new Error('Member membership has expired'), { status: 400 });
  }

  const existing = await client.query(
    `SELECT id FROM loans WHERE book_id=$1 AND member_id=$2 AND status='Issued'`,
    [bookId, memberId],
  );
  if (existing.rows.length > 0) throw Object.assign(new Error('This member already has this book issued'), { status: 400 });

  const loanResult = await client.query(
    `INSERT INTO loans (book_id, member_id, due_date, status, fine, fine_paid)
     VALUES ($1,$2,$3,'Issued',0,false)
     RETURNING *`,
    [bookId, memberId, dueDate],
  );

  await client.query('UPDATE books SET available_copies=available_copies-1 WHERE id=$1', [bookId]);
  await client.query(
    `UPDATE reservations
     SET status='Completed', completed_at=CURRENT_TIMESTAMP, updated_at=CURRENT_TIMESTAMP
     WHERE book_id=$1 AND member_id=$2 AND status IN ('Pending','Ready')`,
    [bookId, memberId],
  );

  return loanResult.rows[0];
}

router.post('/issue', authenticateToken, allowRoles('Admin', 'Librarian'), async (req, res) => {
  const client = await pool.connect();
  try {
    const { bookId, memberId, dueDate } = req.body;
    if (!bookId || !memberId || !dueDate) return res.status(400).json({ message: 'Book ID, member ID and due date are required' });

    await client.query('BEGIN');
    const loan = await issueBook(client, { bookId: Number(bookId), memberId: Number(memberId), dueDate });
    await client.query('COMMIT');

    await writeAudit({ userId: req.user.id, action: 'LOAN_ISSUED', entityType: 'Loan', entityId: loan.id, details: { bookId, memberId, dueDate } });
    res.status(201).json({ message: 'Book issued successfully', loan });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Issue book error:', error);
    res.status(error.status || 500).json({ message: error.message || 'Failed to issue book' });
  } finally {
    client.release();
  }
});

router.post('/issue-by-code', authenticateToken, allowRoles('Admin', 'Librarian'), async (req, res) => {
  const client = await pool.connect();
  try {
    const { isbn, memberCode, dueDate } = req.body;
    if (!isbn || !memberCode || !dueDate) return res.status(400).json({ message: 'ISBN, member code and due date are required' });

    const book = await client.query('SELECT id FROM books WHERE isbn=$1', [String(isbn).trim()]);
    const member = await client.query('SELECT id FROM members WHERE member_code=$1', [String(memberCode).trim()]);
    if (!book.rows[0]) return res.status(404).json({ message: 'ISBN not found' });
    if (!member.rows[0]) return res.status(404).json({ message: 'Member code not found' });

    await client.query('BEGIN');
    const loan = await issueBook(client, { bookId: book.rows[0].id, memberId: member.rows[0].id, dueDate });
    await client.query('COMMIT');

    await writeAudit({ userId: req.user.id, action: 'LOAN_BARCODE_ISSUED', entityType: 'Loan', entityId: loan.id, details: { isbn, memberCode } });
    res.status(201).json({ message: 'Book issued successfully', loan });
  } catch (error) {
    try { await client.query('ROLLBACK'); } catch (_) {}
    console.error('Quick issue error:', error);
    res.status(error.status || 500).json({ message: error.message || 'Failed to issue book' });
  } finally {
    client.release();
  }
});

router.post('/:id/return', authenticateToken, allowRoles('Admin', 'Librarian'), async (req, res) => {
  const client = await pool.connect();
  try {
    const loanId = Number(req.params.id);
    await client.query('BEGIN');

    const loanResult = await client.query('SELECT * FROM loans WHERE id=$1 FOR UPDATE', [loanId]);
    if (loanResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ message: 'Loan not found' });
    }

    const loan = loanResult.rows[0];
    if (loan.status === 'Returned') {
      await client.query('ROLLBACK');
      return res.status(400).json({ message: 'Book has already been returned' });
    }

    const fineResult = await client.query(
      `SELECT GREATEST(CURRENT_DATE - due_date::date,0)::int AS overdue_days FROM loans WHERE id=$1`,
      [loanId],
    );
    const overdueDays = Number(fineResult.rows[0].overdue_days) || 0;
    const fine = overdueDays * finePerDay();

    const updated = await client.query(
      `UPDATE loans
       SET return_date=CURRENT_TIMESTAMP, status='Returned', fine=$1,
           fine_paid=CASE WHEN $1=0 THEN true ELSE fine_paid END,
           fine_paid_at=CASE WHEN $1=0 THEN CURRENT_TIMESTAMP ELSE fine_paid_at END,
           updated_at=CURRENT_TIMESTAMP
       WHERE id=$2
       RETURNING *`,
      [fine, loanId],
    );

    await client.query('UPDATE books SET available_copies=LEAST(total_copies, available_copies+1) WHERE id=$1', [loan.book_id]);

    const nextReservation = await client.query(
      `SELECT r.id, r.member_id, m.name, m.member_code
       FROM reservations r
       JOIN members m ON m.id=r.member_id
       WHERE r.book_id=$1 AND r.status='Pending'
       ORDER BY r.reservation_date ASC
       LIMIT 1
       FOR UPDATE OF r`,
      [loan.book_id],
    );

    if (nextReservation.rows[0]) {
      const r = nextReservation.rows[0];
      await client.query(
        `UPDATE reservations
         SET status='Ready', ready_at=CURRENT_TIMESTAMP,
             expiry_date=CURRENT_TIMESTAMP + INTERVAL '3 days', updated_at=CURRENT_TIMESTAMP
         WHERE id=$1`,
        [r.id],
      );
      await client.query(
        `INSERT INTO notifications (member_id, title, message, type)
         VALUES ($1,'Reserved book ready','Your reserved book is ready for pickup.','Reservation')`,
        [r.member_id],
      );
    }

    await sendReturnMessages(client, loan);

    await client.query('COMMIT');

    await writeAudit({ userId: req.user.id, action: 'LOAN_RETURNED', entityType: 'Loan', entityId: loanId, details: { overdueDays, fine } });
    res.json({ message: 'Book returned successfully', overdueDays, fine, loan: updated.rows[0] });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Return book error:', error);
    res.status(500).json({ message: 'Failed to return book' });
  } finally {
    client.release();
  }
});

router.post('/:id/renew', authenticateToken, allowRoles('Admin', 'Librarian'), async (req, res) => {
  const client = await pool.connect();
  try {
    const id = Number(req.params.id);
    const extraDays = Math.min(30, Math.max(1, Number(req.body.extraDays) || 14));
    await client.query('BEGIN');

    const loanResult = await client.query('SELECT * FROM loans WHERE id=$1 FOR UPDATE', [id]);
    if (!loanResult.rows[0]) {
      await client.query('ROLLBACK');
      return res.status(404).json({ message: 'Loan not found' });
    }
    const loan = loanResult.rows[0];
    if (loan.status !== 'Issued') {
      await client.query('ROLLBACK');
      return res.status(400).json({ message: 'Only active loans can be renewed' });
    }
    if (Number(loan.renew_count || 0) >= 2) {
      await client.query('ROLLBACK');
      return res.status(400).json({ message: 'Maximum renewal limit reached' });
    }

    const pending = await client.query(
      `SELECT COUNT(*)::int AS count FROM reservations
       WHERE book_id=$1 AND status IN ('Pending','Ready') AND member_id<>$2`,
      [loan.book_id, loan.member_id],
    );
    if (pending.rows[0].count > 0) {
      await client.query('ROLLBACK');
      return res.status(400).json({ message: 'Cannot renew because another member has reserved this book' });
    }

    const updated = await client.query(
      `UPDATE loans
       SET due_date=GREATEST(due_date::date,CURRENT_DATE) + ($1 || ' days')::interval,
           renew_count=renew_count+1, last_renewed_at=CURRENT_TIMESTAMP, updated_at=CURRENT_TIMESTAMP
       WHERE id=$2 RETURNING *`,
      [extraDays, id],
    );

    await client.query('COMMIT');
    await writeAudit({ userId: req.user.id, action: 'LOAN_RENEWED', entityType: 'Loan', entityId: id, details: { extraDays } });
    res.json({ message: 'Loan renewed successfully', loan: updated.rows[0] });
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Renew loan error:', error);
    res.status(500).json({ message: 'Failed to renew loan' });
  } finally {
    client.release();
  }
});

router.put('/:id/pay-fine', authenticateToken, allowRoles('Admin', 'Librarian'), async (req, res) => {
  try {
    const id = Number(req.params.id);
    const result = await pool.query(
      `UPDATE loans
       SET fine=GREATEST(
             COALESCE(fine,0),
             CASE
               WHEN status='Issued' AND due_date::date<CURRENT_DATE
                 THEN (CURRENT_DATE-due_date::date) * $2::numeric
               ELSE 0
             END
           ),
           fine_paid=true,
           fine_paid_at=CURRENT_TIMESTAMP,
           updated_at=CURRENT_TIMESTAMP
       WHERE id=$1
         AND COALESCE(fine_paid,false)=false
         AND (
           COALESCE(fine,0)>0
           OR (status='Issued' AND due_date::date<CURRENT_DATE)
         )
       RETURNING *`,
      [id, finePerDay()],
    );
    if (!result.rows[0]) return res.status(400).json({ message: 'No payable fine found for this loan' });

    await writeAudit({ userId: req.user.id, action: 'FINE_PAID', entityType: 'Loan', entityId: id, details: { fine: result.rows[0].fine } });
    
    // PAYMENT_THANK_YOU_NOTIFICATION
    try {
      const paidLoan = result.rows[0];

      if (paidLoan && paidLoan.member_id) {
        await pool.query(
          `INSERT INTO notifications
           (member_id, title, message, type)
           VALUES ($1, $2, $3, $4)`,
          [
            paidLoan.member_id,
            'Fine payment confirmed',
            `Your fine payment of LKR ${Number(
              paidLoan.fine || 0
            ).toFixed(2)} for loan #${id} was received successfully. Thank you for your payment!`,
            'Loan'
          ]
        );
      }
    } catch (notificationError) {
      console.error('Payment notification error:', notificationError);
    }

res.json({ message: 'Fine marked as paid', loan: result.rows[0] });
  } catch (error) {
    console.error('Pay fine error:', error);
    res.status(500).json({ message: 'Failed to update fine payment' });
  }
});

router.get('/:id/receipt', authenticateToken, async (req, res) => {
  try {
    const id = Number(req.params.id);
    const params = [id];
    let extra = '';
    if ((req.user.role || '').toLowerCase() === 'member') {
      params.push(req.user.memberId || -1);
      extra = 'AND l.member_id=$2';
    }

    const result = await pool.query(
      `SELECT l.*, b.title AS book_title, b.isbn, m.member_code, m.name AS member_name
       FROM loans l JOIN books b ON b.id=l.book_id JOIN members m ON m.id=l.member_id
       WHERE l.id=$1 ${extra}`,
      params,
    );
    if (!result.rows[0]) return res.status(404).json({ message: 'Loan receipt not found' });

    res.json({
      receiptNo: `LMS-${String(id).padStart(6, '0')}`,
      generatedAt: new Date().toISOString(),
      ...result.rows[0],
    });
  } catch (error) {
    console.error('Receipt error:', error);
    res.status(500).json({ message: 'Failed to generate receipt' });
  }
});


// ============================================================
// BOOKNEST_SAFE_RETURN_ROUTE
// POST /api/loans/:id/return-safe
// ============================================================

router.post(
  '/:id/return-safe',
  authenticateToken,
  async (req, res) => {
    const client =
      await pool.connect();

    try {
      const role = String(
        req.user?.role || '',
      ).toLowerCase();

      if (
        role !== 'admin' &&
        role !== 'librarian'
      ) {
        return res.status(403).json({
          message:
            'Admin or Librarian access required',
        });
      }

      const id =
        Number(req.params.id);

      if (
        !Number.isInteger(id) ||
        id <= 0
      ) {
        return res.status(400).json({
          message: 'Invalid loan ID',
        });
      }

      await client.query('BEGIN');

      const result =
        await client.query(
          `
          SELECT
            id,
            book_id,
            member_id,
            status,
            due_date,
            GREATEST(
              CURRENT_DATE -
              due_date::date,
              0
            )::int AS overdue_days
          FROM loans
          WHERE id=$1
          FOR UPDATE
          `,
          [id],
        );

      if (!result.rows.length) {
        await client.query('ROLLBACK');

        return res.status(404).json({
          message: 'Loan not found',
        });
      }

      const loan =
        result.rows[0];

      if (
        String(loan.status) !==
        'Issued'
      ) {
        await client.query('ROLLBACK');

        return res.status(409).json({
          message:
            'This loan has already been returned',
        });
      }

      const finePerDay =
        Number(
          process.env.FINE_PER_DAY ||
          50,
        );

      const overdueDays =
        Math.max(
          0,
          Number(
            loan.overdue_days || 0,
          ),
        );

      const fine =
        Number(
          (
            overdueDays *
            finePerDay
          ).toFixed(2),
        );

      const updated =
        await client.query(
          `
          UPDATE loans
          SET
            status='Returned',
            return_date=CURRENT_TIMESTAMP,
            fine=$1
          WHERE id=$2
          RETURNING *
          `,
          [fine, id],
        );

      await client.query(
        `
        UPDATE books
        SET available_copies =
          LEAST(
            total_copies,
            available_copies + 1
          )
        WHERE id=$1
        `,
        [loan.book_id],
      );

      await sendReturnMessages(client, loan);

      await client.query('COMMIT');

      return res.json({
        message:
          'Book returned successfully',

        fine,

        overdueDays,

        loan: updated.rows[0],
      });
    } catch (error) {
      try {
        await client.query(
          'ROLLBACK',
        );
      } catch (_) {}

      console.error(
        'Safe return error:',
        error,
      );

      return res.status(500).json({
        message:
          error.message ||
          'Failed to return book',
      });
    } finally {
      client.release();
    }
  },
);

module.exports = router;
