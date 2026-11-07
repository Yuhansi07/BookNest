
const express = require('express');
const bcrypt = require('bcryptjs');
const pool = require('../db');
const authenticateToken = require('../middleware/auth');
const writeAudit = require('../services/audit');

const router = express.Router();

function adminOnly(
  req,
  res,
  next,
) {
  if (
    String(
      req.user?.role || '',
    ).toLowerCase() !==
    'admin'
  ) {
    return res.status(403).json({
      message:
        'Admin access required',
    });
  }

  next();
}

function validEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(
    email,
  );
}

async function getNextMemberCode(
  client,
) {
  await client.query(
    'LOCK TABLE members IN SHARE ROW EXCLUSIVE MODE',
  );

  const result =
    await client.query(`
      SELECT
        COALESCE(
          MAX(
            CASE
              WHEN
                member_code
                  ~* '^MEM[0-9]+$'
              THEN
                regexp_replace(
                  member_code,
                  '[^0-9]',
                  '',
                  'g'
                )::int
              ELSE
                NULL
            END
          ),
          0
        ) + 1 AS next_no
      FROM members
    `);

  const nextNo =
    Number(
      result.rows[0]?.next_no ||
        1,
    );

  return `MEM${String(
    nextNo,
  ).padStart(3, '0')}`;
}

// ============================================================
// PUBLIC REGISTRATION
// POST /api/registration-requests
// ============================================================

router.post(
  '/',
  async (req, res) => {
    const client =
      await pool.connect();

    try {
      const name = String(
        req.body?.name || '',
      ).trim();

      const email = String(
        req.body?.email || '',
      )
        .trim()
        .toLowerCase();

      const phone = String(
        req.body?.phone || '',
      ).trim();

      const address = String(
        req.body?.address || '',
      ).trim();

      const password = String(
        req.body?.password || '',
      );

      if (
        !name ||
        !email ||
        !password
      ) {
        return res.status(400).json({
          message:
            'Full name, email and password are required',
        });
      }

      if (!validEmail(email)) {
        return res.status(400).json({
          message:
            'Enter a valid email address',
        });
      }

      if (
        password.length < 6
      ) {
        return res.status(400).json({
          message:
            'Password must contain at least 6 characters',
        });
      }

      await client.query(
        'BEGIN',
      );

      const existingUser =
        await client.query(
          `
          SELECT id
          FROM users
          WHERE
            LOWER(email)
              = LOWER($1)
          LIMIT 1
          `,
          [email],
        );

      if (
        existingUser.rows.length
      ) {
        await client.query(
          'ROLLBACK',
        );

        return res.status(409).json({
          message:
            'An account already exists with this email. Please sign in instead',
        });
      }

      const existingRequest =
        await client.query(
          `
          SELECT *
          FROM registration_requests
          WHERE
            LOWER(email)
              = LOWER($1)
          LIMIT 1
          FOR UPDATE
          `,
          [email],
        );

      if (
        existingRequest.rows.length
      ) {
        const previous =
          existingRequest.rows[0];

        if (
          previous.status ===
          'Pending'
        ) {
          await client.query(
            'ROLLBACK',
          );

          return res.status(409).json({
            message:
              'Your registration request is already awaiting administrator approval',
          });
        }

        if (
          previous.status ===
          'Approved'
        ) {
          await client.query(
            'ROLLBACK',
          );

          return res.status(409).json({
            message:
              'This registration has already been approved. Please sign in',
          });
        }

        const passwordHash =
          await bcrypt.hash(
            password,
            12,
          );

        const updated =
          await client.query(
            `
            UPDATE registration_requests

            SET
              name = $1,
              phone = $2,
              address = $3,
              password_hash = $4,
              status = 'Pending',
              rejection_reason = NULL,
              requested_at =
                CURRENT_TIMESTAMP,
              reviewed_at = NULL,
              reviewed_by = NULL,
              created_member_id = NULL,
              created_user_id = NULL,
              updated_at =
                CURRENT_TIMESTAMP

            WHERE
              id = $5

            RETURNING
              id,
              name,
              email,
              phone,
              address,
              status,
              requested_at
            `,
            [
              name,
              phone || null,
              address || null,
              passwordHash,
              previous.id,
            ],
          );

        await client.query(
          'COMMIT',
        );

        return res.status(201).json({
          message:
            'Registration resubmitted successfully. Please wait for administrator approval',

          request:
            updated.rows[0],
        });
      }

      const passwordHash =
        await bcrypt.hash(
          password,
          12,
        );

      const created =
        await client.query(
          `
          INSERT INTO registration_requests
          (
            name,
            email,
            phone,
            address,
            password_hash,
            status
          )
          VALUES
          (
            $1,
            $2,
            $3,
            $4,
            $5,
            'Pending'
          )
          RETURNING
            id,
            name,
            email,
            phone,
            address,
            status,
            requested_at
          `,
          [
            name,
            email,
            phone || null,
            address || null,
            passwordHash,
          ],
        );

      await client.query(
        'COMMIT',
      );

      return res.status(201).json({
        message:
          'Registration submitted successfully. Please wait for administrator approval',

        request:
          created.rows[0],
      });
    } catch (error) {
      try {
        await client.query(
          'ROLLBACK',
        );
      } catch (_) {}

      console.error(
        'Public registration error:',
        error,
      );

      return res.status(500).json({
        message:
          'Failed to submit registration request',
      });
    } finally {
      client.release();
    }
  },
);

// ============================================================
// ADMIN - LIST REGISTRATION REQUESTS
// ============================================================

router.get(
  '/',
  authenticateToken,
  adminOnly,
  async (req, res) => {
    try {
      const status = String(
        req.query.status || '',
      ).trim();

      const search = String(
        req.query.search || '',
      ).trim();

      const params = [];
      const conditions = [];

      if (status) {
        params.push(status);

        conditions.push(
          `LOWER(rr.status) = LOWER($${params.length})`,
        );
      }

      if (search) {
        params.push(
          `%${search}%`,
        );

        conditions.push(`
          (
            rr.name
              ILIKE $${params.length}

            OR

            rr.email
              ILIKE $${params.length}

            OR

            COALESCE(
              rr.phone,
              ''
            )
              ILIKE $${params.length}
          )
        `);
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
            rr.id,
            rr.name,
            rr.email,
            rr.phone,
            rr.address,
            rr.status,
            rr.rejection_reason,
            rr.requested_at,
            rr.reviewed_at,
            rr.reviewed_by,
            rr.created_member_id,
            rr.created_user_id,

            reviewer.name
              AS reviewer_name

          FROM registration_requests rr

          LEFT JOIN users reviewer
            ON reviewer.id =
              rr.reviewed_by

          ${where}

          ORDER BY

            CASE
              WHEN
                rr.status = 'Pending'
              THEN 0

              WHEN
                rr.status = 'Rejected'
              THEN 1

              ELSE 2
            END,

            rr.requested_at DESC
          `,
          params,
        );

      return res.json(
        result.rows,
      );
    } catch (error) {
      console.error(
        'Get registration requests error:',
        error,
      );

      return res.status(500).json({
        message:
          'Failed to load registration requests',
      });
    }
  },
);

// ============================================================
// ADMIN - APPROVE REGISTRATION
// ============================================================

router.post(
  '/:id/approve',
  authenticateToken,
  adminOnly,
  async (req, res) => {
    const client =
      await pool.connect();

    try {
      const requestId =
        Number(req.params.id);

      const adminId =
        Number(
          req.user?.id ||
            req.user?.userId,
        );

      if (!requestId) {
        return res.status(400).json({
          message:
            'Invalid registration request',
        });
      }

      await client.query(
        'BEGIN',
      );

      const requestResult =
        await client.query(
          `
          SELECT *
          FROM registration_requests
          WHERE id = $1
          FOR UPDATE
          `,
          [requestId],
        );

      if (
        !requestResult.rows.length
      ) {
        await client.query(
          'ROLLBACK',
        );

        return res.status(404).json({
          message:
            'Registration request not found',
        });
      }

      const request =
        requestResult.rows[0];

      if (
        request.status !==
        'Pending'
      ) {
        await client.query(
          'ROLLBACK',
        );

        return res.status(400).json({
          message:
            `This request is already ${String(
              request.status,
            ).toLowerCase()}`,
        });
      }

      const duplicateUser =
        await client.query(
          `
          SELECT id
          FROM users
          WHERE
            LOWER(email)
              = LOWER($1)
          LIMIT 1
          `,
          [request.email],
        );

      if (
        duplicateUser.rows.length
      ) {
        await client.query(
          'ROLLBACK',
        );

        return res.status(409).json({
          message:
            'A user account already exists with this email',
        });
      }

      let memberId;
      let memberCode;

      const existingMember =
        await client.query(
          `
          SELECT
            id,
            member_code
          FROM members
          WHERE
            LOWER(
              COALESCE(
                email,
                ''
              )
            ) = LOWER($1)
          LIMIT 1
          FOR UPDATE
          `,
          [request.email],
        );

      if (
        existingMember.rows.length
      ) {
        memberId =
          Number(
            existingMember.rows[0].id,
          );

        memberCode =
          existingMember.rows[0]
            .member_code;

        await client.query(
          `
          UPDATE members
          SET
            name = $1,

            phone =
              COALESCE(
                NULLIF(
                  $2,
                  ''
                ),
                phone
              ),

            address =
              COALESCE(
                NULLIF(
                  $3,
                  ''
                ),
                address
              ),

            status = 'Active',

            updated_at =
              CURRENT_TIMESTAMP

          WHERE
            id = $4
          `,
          [
            request.name,
            request.phone || '',
            request.address || '',
            memberId,
          ],
        );
      } else {
        memberCode =
          await getNextMemberCode(
            client,
          );

        const memberCreated =
          await client.query(
            `
            INSERT INTO members
            (
              member_code,
              name,
              email,
              phone,
              address,
              status
            )
            VALUES
            (
              $1,
              $2,
              $3,
              $4,
              $5,
              'Active'
            )
            RETURNING
              id,
              member_code
            `,
            [
              memberCode,
              request.name,
              request.email,
              request.phone || null,
              request.address || null,
            ],
          );

        memberId =
          Number(
            memberCreated.rows[0].id,
          );

        memberCode =
          memberCreated.rows[0]
            .member_code;
      }

      const userCreated =
        await client.query(
          `
          INSERT INTO users
          (
            name,
            email,
            password_hash,
            role,
            member_id,
            is_active
          )
          VALUES
          (
            $1,
            $2,
            $3,
            'Member',
            $4,
            TRUE
          )
          RETURNING
            id,
            name,
            email,
            role,
            member_id,
            is_active
          `,
          [
            request.name,
            request.email,
            request.password_hash,
            memberId,
          ],
        );

      const user =
        userCreated.rows[0];

      await client.query(
        `
        UPDATE registration_requests

        SET
          status = 'Approved',
          rejection_reason = NULL,
          reviewed_at =
            CURRENT_TIMESTAMP,
          reviewed_by = $1,
          created_member_id = $2,
          created_user_id = $3,
          updated_at =
            CURRENT_TIMESTAMP

        WHERE
          id = $4
        `,
        [
          adminId || null,
          memberId,
          user.id,
          requestId,
        ],
      );

      await client.query(
        'COMMIT',
      );

      try {
        await writeAudit({
          userId:
            adminId,

          action:
            'MEMBER_REGISTRATION_APPROVED',

          entityType:
            'RegistrationRequest',

          entityId:
            requestId,

          details: {
            email:
              request.email,

            memberId,

            memberCode,

            userId:
              user.id,
          },
        });
      } catch (auditError) {
        console.error(
          'Registration approval audit error:',
          auditError,
        );
      }

      return res.json({
        message:
          `Registration approved. Member ${memberCode} can now sign in`,

        member: {
          id:
            memberId,

          member_code:
            memberCode,

          name:
            request.name,

          email:
            request.email,
        },

        user,
      });
    } catch (error) {
      try {
        await client.query(
          'ROLLBACK',
        );
      } catch (_) {}

      console.error(
        'Approve registration error:',
        error,
      );

      return res.status(500).json({
        message:
          error.message ||
          'Failed to approve registration',
      });
    } finally {
      client.release();
    }
  },
);

// ============================================================
// ADMIN - REJECT REGISTRATION
// ============================================================

router.post(
  '/:id/reject',
  authenticateToken,
  adminOnly,
  async (req, res) => {
    try {
      const requestId =
        Number(req.params.id);

      const adminId =
        Number(
          req.user?.id ||
            req.user?.userId,
        );

      const reason =
        String(
          req.body?.reason || '',
        ).trim();

      const result =
        await pool.query(
          `
          UPDATE registration_requests

          SET
            status = 'Rejected',

            rejection_reason = $1,

            reviewed_at =
              CURRENT_TIMESTAMP,

            reviewed_by = $2,

            updated_at =
              CURRENT_TIMESTAMP

          WHERE
            id = $3
            AND
            status = 'Pending'

          RETURNING
            id,
            name,
            email,
            status,
            rejection_reason,
            reviewed_at
          `,
          [
            reason ||
              'Registration request was not approved',

            adminId ||
              null,

            requestId,
          ],
        );

      if (
        !result.rows.length
      ) {
        return res.status(404).json({
          message:
            'Pending registration request not found',
        });
      }

      try {
        await writeAudit({
          userId:
            adminId,

          action:
            'MEMBER_REGISTRATION_REJECTED',

          entityType:
            'RegistrationRequest',

          entityId:
            requestId,

          details: {
            email:
              result.rows[0].email,

            reason:
              result.rows[0]
                .rejection_reason,
          },
        });
      } catch (auditError) {
        console.error(
          'Registration rejection audit error:',
          auditError,
        );
      }

      return res.json({
        message:
          'Registration request rejected',

        request:
          result.rows[0],
      });
    } catch (error) {
      console.error(
        'Reject registration error:',
        error,
      );

      return res.status(500).json({
        message:
          'Failed to reject registration request',
      });
    }
  },
);

module.exports = router;
