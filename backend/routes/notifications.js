const express = require('express');
const pool = require('../db');
const authenticateToken = require('../middleware/auth');

const router = express.Router();

function getMemberId(req) {
  return Number(
    req.user?.memberId ??
    req.user?.member_id ??
    0
  );
}

function isStaff(req) {
  const role = String(
    req.user?.role || ''
  ).toLowerCase();

  return (
    role === 'admin' ||
    role === 'librarian'
  );
}


// LMS_LOAN_NOTICES_V2
async function syncLoanNotices(memberId) {
  const tasks = [
    [
      'Book issued',
      `concat('Book "',b.title,'" issued. Return by ',
        to_char(l.due_date::date,'YYYY-MM-DD'))`,
      `l.status='Issued' AND l.issue_date::date >= CURRENT_DATE-30`,
      'LoanIssued'
    ],
    [
      'Due date reminder',
      `concat('Book "',b.title,'" is due on ',
        to_char(l.due_date::date,'YYYY-MM-DD'))`,
      `l.status='Issued' AND l.due_date::date
        BETWEEN CURRENT_DATE AND CURRENT_DATE+2`,
      'DueSoon'
    ],
    [
      'Overdue book',
      `concat('Book "',b.title,'" was due on ',
        to_char(l.due_date::date,'YYYY-MM-DD'))`,
      `l.status='Issued' AND l.due_date::date < CURRENT_DATE`,
      'Overdue'
    ],
    [
      'Return confirmed',
      `concat('Return confirmed for "',b.title,'". Thank you!')`,
      `l.status='Returned' AND
        l.return_date::date >= CURRENT_DATE-30`,
      'LoanReturned'
    ],
    [
      'Please rate your book',
      `concat('You returned "',b.title,
        '". Tap Rate now to share your review.')`,
      `l.status='Returned' AND
        l.return_date::date >= CURRENT_DATE-30`,
      'Review'
    ]
  ];

  for (const [title, message, condition, prefix] of tasks) {
    const typeExpr = prefix === 'Review'
      ? `'Review:' || l.book_id::text || ':' || l.id::text`
      : `'${prefix}:' || l.id::text`;

    await pool.query(`
      INSERT INTO notifications(member_id,title,message,type)
      SELECT l.member_id,$2,${message},${typeExpr}
      FROM loans l
      JOIN books b ON b.id=l.book_id
      WHERE l.member_id=$1 AND ${condition}
        AND NOT EXISTS (
          SELECT 1 FROM notifications x
          WHERE x.member_id=l.member_id
            AND x.type=${typeExpr}
        )
      ON CONFLICT DO NOTHING
    `, [memberId,title]);
  }
}

router.get(
  '/',
  authenticateToken,
  async (req, res) => {
    try {
      const memberId = getMemberId(req);

      if (memberId > 0) {
        try {
          await syncLoanNotices(memberId);
        } catch (e) {
          console.error('Loan notification sync:', e.message);
        }
        // Check whether this member came from
        // an approved public registration.
        const approved = await pool.query(
          `SELECT
             m.member_code,
             rr.id AS registration_request_id
           FROM members m
           LEFT JOIN LATERAL (
             SELECT id
             FROM registration_requests
             WHERE created_member_id = m.id
               AND LOWER(status) = 'approved'
             ORDER BY
               reviewed_at DESC NULLS LAST,
               id DESC
             LIMIT 1
           ) rr ON TRUE
           WHERE m.id = $1
           LIMIT 1`,
          [memberId],
        );

        if (approved.rows.length) {
          const row = approved.rows[0];

          if (
            row.registration_request_id &&
            row.member_code
          ) {
            // Back-fill approval notification if
            // an older approval did not create it.
            await pool.query(
              `INSERT INTO notifications
               (
                 member_id,
                 title,
                 message,
                 type,
                 is_read
               )
               SELECT
                 $1,
                 'Membership approved',
                 $2,
                 'Account',
                 FALSE
               WHERE NOT EXISTS (
                 SELECT 1
                 FROM notifications
                 WHERE member_id = $1
                   AND title = 'Membership approved'
                   AND message ILIKE $3
               )`,
              [
                memberId,
                `Your membership has been approved. Your Member ID is ${row.member_code}. You can sign in using either your email address or ${row.member_code} with your password.`,
                `%${row.member_code}%`,
              ],
            );
          }
        }

        const result = await pool.query(
          `SELECT
             id,
             member_id,
             title,
             message,
             type,
             COALESCE(is_read,FALSE) AS is_read,
             created_at
           FROM notifications
           WHERE member_id = $1
           ORDER BY created_at DESC, id DESC
           LIMIT 100`,
          [memberId],
        );

        return res.json(result.rows);
      }

      // Staff only receive system-wide notifications here.
      if (isStaff(req)) {
        const result = await pool.query(
          `SELECT
             id,
             member_id,
             title,
             message,
             type,
             COALESCE(is_read,FALSE) AS is_read,
             created_at
           FROM notifications
           WHERE member_id IS NULL
           ORDER BY created_at DESC, id DESC
           LIMIT 100`,
        );

        return res.json(result.rows);
      }

      return res.json([]);
    } catch (error) {
      console.error(
        'Get notifications error:',
        error,
      );

      return res.status(500).json({
        message:
          'Failed to load notifications',
      });
    }
  },
);


router.patch(
  '/read-all',
  authenticateToken,
  async (req, res) => {
    try {
      const memberId = getMemberId(req);

      if (memberId > 0) {
        await pool.query(
          `UPDATE notifications
           SET is_read=TRUE
           WHERE member_id=$1`,
          [memberId],
        );
      }

      return res.json({
        message:
          'Notifications marked as read',
      });
    } catch (error) {
      console.error(
        'Read all notifications error:',
        error,
      );

      return res.status(500).json({
        message:
          'Failed to update notifications',
      });
    }
  },
);


router.patch(
  '/:id/read',
  authenticateToken,
  async (req, res) => {
    try {
      const id = Number(req.params.id);
      const memberId = getMemberId(req);

      let result;

      if (memberId > 0) {
        result = await pool.query(
          `UPDATE notifications
           SET is_read=TRUE
           WHERE id=$1
             AND member_id=$2
           RETURNING *`,
          [id, memberId],
        );
      } else if (isStaff(req)) {
        result = await pool.query(
          `UPDATE notifications
           SET is_read=TRUE
           WHERE id=$1
           RETURNING *`,
          [id],
        );
      } else {
        return res.status(403).json({
          message: 'Access denied',
        });
      }

      if (!result.rows.length) {
        return res.status(404).json({
          message:
            'Notification not found',
        });
      }

      return res.json(result.rows[0]);
    } catch (error) {
      console.error(
        'Read notification error:',
        error,
      );

      return res.status(500).json({
        message:
          'Failed to update notification',
      });
    }
  },
);

module.exports = router;
