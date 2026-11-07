
const express = require('express');
const pool = require('../db');

const authenticateToken =
  require('../middleware/auth');

const allowRoles =
  require('../middleware/roles');

const writeAudit =
  require('../services/audit');

const router =
  express.Router();

// ============================================================
// LIST MEMBERS
// ============================================================

router.get(
  '/',
  authenticateToken,
  async (req, res) => {
    try {
      const search = String(
        req.query.search || '',
      ).trim();

      const status = String(
        req.query.status || '',
      ).trim();

      const params = [];
      const conditions = [];

      if (search) {
        params.push(
          `%${search}%`,
        );

        conditions.push(`
          (
            m.name
              ILIKE $${params.length}

            OR

            m.member_code
              ILIKE $${params.length}

            OR

            COALESCE(
              m.email,
              ''
            )
              ILIKE $${params.length}

            OR

            COALESCE(
              m.phone,
              ''
            )
              ILIKE $${params.length}
          )
        `);
      }

      if (status) {
        params.push(status);

        conditions.push(
          `m.status = $${params.length}`,
        );
      }

      if (
        String(
          req.user.role || '',
        ).toLowerCase() ===
        'member'
      ) {
        if (
          !req.user.memberId
        ) {
          return res.json([]);
        }

        params.push(
          req.user.memberId,
        );

        conditions.push(
          `m.id = $${params.length}`,
        );
      }

      const where =
        conditions.length
          ? `WHERE ${conditions.join(
              ' AND ',
            )}`
          : '';

      const result =
        await pool.query(
          `
          SELECT
            m.*,

            COALESCE(
              loan_stats.active_loan_count,
              0
            )::int
              AS active_loan_count,

            COALESCE(
              loan_stats.unpaid_fines,
              0
            )::numeric(12,2)
              AS unpaid_fines,

            COALESCE(
              reservation_stats.active_reservation_count,
              0
            )::int
              AS active_reservation_count

          FROM members m

          LEFT JOIN LATERAL
          (
            SELECT

              COUNT(*)
                FILTER
                (
                  WHERE
                    l.status = 'Issued'
                )::int
                AS active_loan_count,

              COALESCE
              (
                SUM(l.fine)
                  FILTER
                  (
                    WHERE
                      COALESCE(
                        l.fine_paid,
                        FALSE
                      ) = FALSE
                  ),
                0
              )
                AS unpaid_fines

            FROM loans l

            WHERE
              l.member_id = m.id

          ) loan_stats
            ON TRUE

          LEFT JOIN LATERAL
          (
            SELECT

              COUNT(*)
                FILTER
                (
                  WHERE
                    r.status
                    IN
                    (
                      'Pending',
                      'Ready'
                    )
                )::int
                AS active_reservation_count

            FROM reservations r

            WHERE
              r.member_id = m.id

          ) reservation_stats
            ON TRUE

          ${where}

          ORDER BY
            m.name ASC
          `,
          params,
        );

      return res.json(
        result.rows,
      );
    } catch (error) {
      console.error(
        'Get members error:',
        error,
      );

      return res.status(500).json({
        message:
          'Failed to get members',
      });
    }
  },
);

// ============================================================
// MEMBER PROFILE
// ============================================================

router.get(
  '/:id/profile',
  authenticateToken,
  async (req, res) => {
    try {
      const id =
        Number(req.params.id);

      if (
        String(
          req.user.role || '',
        ).toLowerCase() ===
          'member' &&
        Number(
          req.user.memberId,
        ) !== id
      ) {
        return res.status(403).json({
          message:
            'You can only view your own member profile',
        });
      }

      const memberResult =
        await pool.query(
          `
          SELECT
            m.*,

            COALESCE(
              loan_stats.total_loans,
              0
            )::int
              AS total_loans,

            COALESCE(
              loan_stats.active_loans,
              0
            )::int
              AS active_loans,

            COALESCE(
              loan_stats.unpaid_fines,
              0
            )::numeric(12,2)
              AS unpaid_fines,

            COALESCE(
              reservation_stats.active_reservations,
              0
            )::int
              AS active_reservations

          FROM members m

          LEFT JOIN LATERAL
          (
            SELECT

              COUNT(*)::int
                AS total_loans,

              COUNT(*)
                FILTER
                (
                  WHERE
                    l.status = 'Issued'
                )::int
                AS active_loans,

              COALESCE
              (
                SUM(l.fine)
                  FILTER
                  (
                    WHERE
                      COALESCE(
                        l.fine_paid,
                        FALSE
                      ) = FALSE
                  ),
                0
              )
                AS unpaid_fines

            FROM loans l

            WHERE
              l.member_id = m.id

          ) loan_stats
            ON TRUE

          LEFT JOIN LATERAL
          (
            SELECT

              COUNT(*)
                FILTER
                (
                  WHERE
                    r.status
                    IN
                    (
                      'Pending',
                      'Ready'
                    )
                )::int
                AS active_reservations

            FROM reservations r

            WHERE
              r.member_id = m.id

          ) reservation_stats
            ON TRUE

          WHERE
            m.id = $1
          `,
          [id],
        );

      if (
        !memberResult.rows.length
      ) {
        return res.status(404).json({
          message:
            'Member not found',
        });
      }

      const loans =
        await pool.query(
          `
          SELECT
            l.*,
            b.title
              AS book_title,
            b.isbn,

            CASE

              WHEN
                l.status = 'Issued'
                AND
                l.due_date::date
                  < CURRENT_DATE

              THEN
                'Overdue'

              ELSE
                l.status

            END
              AS display_status

          FROM loans l

          JOIN books b
            ON b.id = l.book_id

          WHERE
            l.member_id = $1

          ORDER BY
            l.issue_date DESC
          `,
          [id],
        );

      const reservations =
        await pool.query(
          `
          SELECT
            r.*,
            b.title
              AS book_title,
            b.isbn

          FROM reservations r

          JOIN books b
            ON b.id = r.book_id

          WHERE
            r.member_id = $1

          ORDER BY
            r.reservation_date DESC
          `,
          [id],
        );

      return res.json({
        member:
          memberResult.rows[0],

        loans:
          loans.rows,

        reservations:
          reservations.rows,
      });
    } catch (error) {
      console.error(
        'Member profile error:',
        error,
      );

      return res.status(500).json({
        message:
          'Failed to load member profile',
      });
    }
  },
);

// ============================================================
// CREATE MEMBER
// ============================================================

router.post(
  '/',
  authenticateToken,
  allowRoles(
    'Admin',
    'Librarian',
  ),
  async (req, res) => {
    try {
      const {
        memberCode,
        name,
        email,
        phone,
        address,
        status,
        membershipExpiry,
        notes,
      } = req.body;

      if (
        !memberCode ||
        !name
      ) {
        return res.status(400).json({
          message:
            'Member code and name are required',
        });
      }

      const result =
        await pool.query(
          `
          INSERT INTO members
          (
            member_code,
            name,
            email,
            phone,
            address,
            status,
            membership_expiry,
            notes
          )
          VALUES
          (
            $1,
            $2,
            $3,
            $4,
            $5,
            $6,
            $7,
            $8
          )
          RETURNING *
          `,
          [
            memberCode.trim(),
            name.trim(),

            email?.trim() ||
              null,

            phone?.trim() ||
              null,

            address?.trim() ||
              null,

            status ||
              'Active',

            membershipExpiry ||
              null,

            notes?.trim() ||
              null,
          ],
        );

      await writeAudit({
        userId:
          req.user.id,

        action:
          'MEMBER_CREATED',

        entityType:
          'Member',

        entityId:
          result.rows[0].id,

        details: {
          memberCode,
          name,
        },
      });

      return res
        .status(201)
        .json(
          result.rows[0],
        );
    } catch (error) {
      console.error(
        'Create member error:',
        error,
      );

      if (
        error.code === '23505'
      ) {
        return res.status(409).json({
          message:
            'Member code or email already exists',
        });
      }

      return res.status(500).json({
        message:
          'Failed to create member',
      });
    }
  },
);

// ============================================================
// UPDATE MEMBER
// ============================================================

router.put(
  '/:id',
  authenticateToken,
  allowRoles(
    'Admin',
    'Librarian',
  ),
  async (req, res) => {
    try {
      const id =
        Number(req.params.id);

      const {
        memberCode,
        name,
        email,
        phone,
        address,
        status,
        membershipExpiry,
        notes,
      } = req.body;

      const result =
        await pool.query(
          `
          UPDATE members

          SET
            member_code = $1,
            name = $2,
            email = $3,
            phone = $4,
            address = $5,
            status = $6,
            membership_expiry = $7,
            notes = $8,
            updated_at =
              CURRENT_TIMESTAMP

          WHERE
            id = $9

          RETURNING *
          `,
          [
            memberCode?.trim(),
            name?.trim(),

            email?.trim() ||
              null,

            phone?.trim() ||
              null,

            address?.trim() ||
              null,

            status ||
              'Active',

            membershipExpiry ||
              null,

            notes?.trim() ||
              null,

            id,
          ],
        );

      if (
        !result.rows.length
      ) {
        return res.status(404).json({
          message:
            'Member not found',
        });
      }

      await writeAudit({
        userId:
          req.user.id,

        action:
          'MEMBER_UPDATED',

        entityType:
          'Member',

        entityId:
          id,

        details: {
          name:
            result.rows[0].name,

          status:
            result.rows[0].status,
        },
      });

      return res.json(
        result.rows[0],
      );
    } catch (error) {
      console.error(
        'Update member error:',
        error,
      );

      return res.status(500).json({
        message:
          'Failed to update member',
      });
    }
  },
);

// ============================================================
// DELETE MEMBER
// ============================================================

router.delete(
  '/:id',
  authenticateToken,
  allowRoles('Admin'),
  async (req, res) => {
    try {
      const id =
        Number(req.params.id);

      const active =
        await pool.query(
          `
          SELECT
            COUNT(*)::int
              AS count

          FROM loans

          WHERE
            member_id = $1
            AND
            status = 'Issued'
          `,
          [id],
        );

      if (
        active.rows[0].count > 0
      ) {
        return res.status(400).json({
          message:
            'Cannot delete a member with active loans',
        });
      }

      const linkedUser =
        await pool.query(
          `
          SELECT id
          FROM users
          WHERE member_id = $1
          LIMIT 1
          `,
          [id],
        );

      if (
        linkedUser.rows.length
      ) {
        return res.status(400).json({
          message:
            'This member has a linked login account. Remove or unlink the user account first',
        });
      }

      const result =
        await pool.query(
          `
          DELETE FROM members
          WHERE id = $1
          RETURNING
            id,
            name
          `,
          [id],
        );

      if (
        !result.rows.length
      ) {
        return res.status(404).json({
          message:
            'Member not found',
        });
      }

      await writeAudit({
        userId:
          req.user.id,

        action:
          'MEMBER_DELETED',

        entityType:
          'Member',

        entityId:
          id,

        details: {
          name:
            result.rows[0].name,
        },
      });

      return res.json({
        message:
          'Member deleted successfully',
      });
    } catch (error) {
      console.error(
        'Delete member error:',
        error,
      );

      return res.status(500).json({
        message:
          'Failed to delete member',
      });
    }
  },
);

module.exports = router;
