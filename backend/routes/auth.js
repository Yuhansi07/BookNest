
const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../db');
const authenticateToken = require('../middleware/auth');

const router = express.Router();

function normalizeRole(role) {
  const value = String(role || '').trim().toLowerCase();

  if (value === 'admin') return 'Admin';
  if (value === 'librarian') return 'Librarian';
  if (value === 'member') return 'Member';

  return role;
}

function makePayload(user) {
  return {
    id: Number(user.id),
    userId: Number(user.id),
    name: user.name,
    email: user.email,
    role: normalizeRole(user.role),

    memberId: user.member_id
      ? Number(user.member_id)
      : null,

    member_id: user.member_id
      ? Number(user.member_id)
      : null,

    memberCode: user.member_code || null,
    member_code: user.member_code || null,
  };
}

function sign(payload) {
  return jwt.sign(
    payload,
    process.env.JWT_SECRET ||
      'library_management_secret_2026',
    {
      expiresIn: '12h',
    },
  );
}

// ============================================================
// LOGIN
// Email OR Member ID
// ============================================================

router.post('/login', async (req, res) => {
  try {
    const identifier = String(
      req.body?.identifier ??
        req.body?.email ??
        req.body?.memberCode ??
        '',
    ).trim();

    const password = String(
      req.body?.password || '',
    );

    if (!identifier || !password) {
      return res.status(400).json({
        message:
          'Email / Member ID and password are required',
      });
    }

    const result = await pool.query(
      `
      SELECT
        u.id,
        u.name,
        u.email,
        u.password_hash,
        u.role,
        u.member_id,
        COALESCE(
          u.is_active,
          TRUE
        ) AS is_active,
        m.member_code
      FROM users u
      LEFT JOIN members m
        ON m.id = u.member_id
      WHERE
        LOWER(u.email) = LOWER($1)
        OR
        UPPER(
          COALESCE(
            m.member_code,
            ''
          )
        ) = UPPER($1)
      LIMIT 1
      `,
      [identifier],
    );

    // --------------------------------------------------------
    // No user account found.
    // Check whether this email has a public registration.
    // --------------------------------------------------------

    if (!result.rows.length) {
      if (identifier.includes('@')) {
        const registration =
          await pool.query(
            `
            SELECT
              status,
              rejection_reason
            FROM registration_requests
            WHERE LOWER(email) = LOWER($1)
            ORDER BY requested_at DESC
            LIMIT 1
            `,
            [identifier],
          );

        if (registration.rows.length) {
          const request =
            registration.rows[0];

          if (
            request.status === 'Pending'
          ) {
            return res.status(403).json({
              message:
                'Your account is awaiting administrator approval',
            });
          }

          if (
            request.status === 'Rejected'
          ) {
            return res.status(403).json({
              message:
                request.rejection_reason ||
                'Your registration request was not approved. You may submit a new request',
            });
          }

          if (
            request.status === 'Approved'
          ) {
            return res.status(403).json({
              message:
                'Your registration was approved, but the login account could not be found. Contact the administrator',
            });
          }
        }
      }

      return res.status(401).json({
        message:
          'Invalid email / Member ID or password',
      });
    }

    const user = result.rows[0];

    if (!user.is_active) {
      return res.status(403).json({
        message:
          'This account is inactive',
      });
    }

    const validPassword =
      await bcrypt.compare(
        password,
        user.password_hash,
      );

    if (!validPassword) {
      return res.status(401).json({
        message:
          'Invalid email / Member ID or password',
      });
    }

    const payload =
      makePayload(user);

    const token =
      sign(payload);

    return res.json({
      token,
      user: payload,
    });
  } catch (error) {
    console.error(
      'Login error:',
      error,
    );

    return res.status(500).json({
      message: 'Login failed',
    });
  }
});

// ============================================================
// EXISTING MEMBER SELF-ACTIVATION
// ============================================================

router.post(
  '/member-register',
  async (req, res) => {
    const client =
      await pool.connect();

    try {
      const memberCode = String(
        req.body?.memberCode || '',
      ).trim();

      const contact = String(
        req.body?.registeredContact ??
          req.body?.email ??
          req.body?.phone ??
          '',
      ).trim();

      const password = String(
        req.body?.password || '',
      );

      if (
        !memberCode ||
        !contact ||
        !password
      ) {
        return res.status(400).json({
          message:
            'Member ID, registered email/phone and password are required',
        });
      }

      if (password.length < 6) {
        return res.status(400).json({
          message:
            'Password must contain at least 6 characters',
        });
      }

      await client.query('BEGIN');

      const memberResult =
        await client.query(
          `
          SELECT
            id,
            member_code,
            name,
            email,
            phone,
            status
          FROM members
          WHERE
            UPPER(member_code)
              = UPPER($1)
            AND
            (
              LOWER(
                COALESCE(
                  email,
                  ''
                )
              ) = LOWER($2)

              OR

              regexp_replace(
                COALESCE(
                  phone,
                  ''
                ),
                '[^0-9]',
                '',
                'g'
              )
              =
              regexp_replace(
                $2,
                '[^0-9]',
                '',
                'g'
              )
            )
          LIMIT 1
          FOR UPDATE
          `,
          [
            memberCode,
            contact,
          ],
        );

      if (
        !memberResult.rows.length
      ) {
        await client.query(
          'ROLLBACK',
        );

        return res.status(404).json({
          message:
            'Member ID and registered email/phone do not match a library member record',
        });
      }

      const member =
        memberResult.rows[0];

      if (
        String(
          member.status || '',
        ).toLowerCase() !== 'active'
      ) {
        await client.query(
          'ROLLBACK',
        );

        return res.status(403).json({
          message:
            'This member record is not active',
        });
      }

      if (
        !String(
          member.email || '',
        ).trim()
      ) {
        await client.query(
          'ROLLBACK',
        );

        return res.status(400).json({
          message:
            'This member record has no email address. Ask the librarian to add one first',
        });
      }

      const existing =
        await client.query(
          `
          SELECT
            id,
            member_id,
            email
          FROM users
          WHERE
            member_id = $1
            OR
            LOWER(email)
              = LOWER($2)
          LIMIT 1
          `,
          [
            member.id,
            member.email,
          ],
        );

      if (existing.rows.length) {
        await client.query(
          'ROLLBACK',
        );

        return res.status(409).json({
          message:
            'A login account already exists for this member. Sign in using the Member ID or registered email',
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
            LOWER($2),
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
            member.name,
            member.email,
            passwordHash,
            member.id,
          ],
        );

      const row = {
        ...created.rows[0],

        member_code:
          member.member_code,
      };

      const payload =
        makePayload(row);

      await client.query(
        'COMMIT',
      );

      return res.status(201).json({
        message:
          'Member account activated successfully',

        token:
          sign(payload),

        user:
          payload,
      });
    } catch (error) {
      try {
        await client.query(
          'ROLLBACK',
        );
      } catch (_) {}

      console.error(
        'Member account activation error:',
        error,
      );

      return res.status(500).json({
        message:
          error.message ||
          'Failed to activate member account',
      });
    } finally {
      client.release();
    }
  },
);

// ============================================================
// CURRENT USER
// ============================================================

router.get(
  '/me',
  authenticateToken,
  async (req, res) => {
    try {
      const id =
        req.user?.id ||
        req.user?.userId;

      const result =
        await pool.query(
          `
          SELECT
            u.id,
            u.name,
            u.email,
            u.role,
            u.member_id,
            COALESCE(
              u.is_active,
              TRUE
            ) AS is_active,
            m.member_code
          FROM users u
          LEFT JOIN members m
            ON m.id = u.member_id
          WHERE u.id = $1
          LIMIT 1
          `,
          [id],
        );

      if (!result.rows.length) {
        return res.status(404).json({
          message:
            'User not found',
        });
      }

      const user =
        result.rows[0];

      if (!user.is_active) {
        return res.status(403).json({
          message:
            'This account is inactive',
        });
      }

      const payload =
        makePayload(user);

      return res.json({
        ...payload,

        isActive:
          user.is_active,

        user:
          payload,
      });
    } catch (error) {
      console.error(
        'Auth me error:',
        error,
      );

      return res.status(500).json({
        message:
          'Failed to load session',
      });
    }
  },
);

module.exports = router;
