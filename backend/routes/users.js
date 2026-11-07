
const express = require('express');
const bcrypt = require('bcryptjs');
const pool = require('../db');
const authenticateToken = require('../middleware/auth');

const router = express.Router();

function adminOnly(
  req,
  res,
  next,
) {
  if (
    String(
      req.user?.role || '',
    ).toLowerCase() !== 'admin'
  ) {
    return res.status(403).json({
      message:
        'Admin access required',
    });
  }

  next();
}

function normalizeRole(role) {
  const value = String(
    role || '',
  )
    .trim()
    .toLowerCase();

  if (value === 'admin') {
    return 'Admin';
  }

  if (value === 'librarian') {
    return 'Librarian';
  }

  if (value === 'member') {
    return 'Member';
  }

  return null;
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
              WHEN member_code
                ~* '^MEM[0-9]+$'
              THEN
                regexp_replace(
                  member_code,
                  '[^0-9]',
                  '',
                  'g'
                )::int
              ELSE NULL
            END
          ),
          0
        ) + 1 AS next_no
      FROM members
    `);

  const nextNumber =
    Number(
      result.rows[0]?.next_no ||
        1,
    );

  return `MEM${String(
    nextNumber,
  ).padStart(3, '0')}`;
}

async function ensureMember(
  client,
  {
    name,
    email,
    memberId,
  },
) {
  if (memberId) {
    const result =
      await client.query(
        `
        SELECT id
        FROM members
        WHERE id = $1
        LIMIT 1
        `,
        [Number(memberId)],
      );

    if (result.rows.length) {
      return Number(
        result.rows[0].id,
      );
    }
  }

  const byEmail =
    await client.query(
      `
      SELECT id
      FROM members
      WHERE
        LOWER(
          COALESCE(
            email,
            ''
          )
        ) = LOWER($1)
      LIMIT 1
      `,
      [email],
    );

  if (byEmail.rows.length) {
    return Number(
      byEmail.rows[0].id,
    );
  }

  const memberCode =
    await getNextMemberCode(
      client,
    );

  const created =
    await client.query(
      `
      INSERT INTO members
      (
        member_code,
        name,
        email,
        phone,
        status
      )
      VALUES
      (
        $1,
        $2,
        $3,
        $4,
        'Active'
      )
      RETURNING id
      `,
      [
        memberCode,
        name,
        email,
        '',
      ],
    );

  return Number(
    created.rows[0].id,
  );
}

// ============================================================
// GET USERS
// ============================================================

router.get(
  '/',
  authenticateToken,
  adminOnly,
  async (req, res) => {
    try {
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

            m.member_code,

            m.name
              AS member_name

          FROM users u

          LEFT JOIN members m
            ON m.id = u.member_id

          ORDER BY u.id
          `,
        );

      return res.json(
        result.rows,
      );
    } catch (error) {
      console.error(
        'Get users error:',
        error,
      );

      return res.status(500).json({
        message:
          'Failed to get users',
      });
    }
  },
);

// ============================================================
// CREATE USER
// ============================================================

router.post(
  '/',
  authenticateToken,
  adminOnly,
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

      const password = String(
        req.body?.password || '',
      );

      const role =
        normalizeRole(
          req.body?.role,
        );

      const requestedMemberId =
        req.body?.memberId ??
        req.body?.member_id ??
        null;

      if (
        !name ||
        !email ||
        !password ||
        !role
      ) {
        return res.status(400).json({
          message:
            'Name, email, password and valid role are required',
        });
      }

      if (password.length < 6) {
        return res.status(400).json({
          message:
            'Password must have at least 6 characters',
        });
      }

      await client.query(
        'BEGIN',
      );

      const duplicate =
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
        duplicate.rows.length
      ) {
        await client.query(
          'ROLLBACK',
        );

        return res.status(409).json({
          message:
            'Email already exists',
        });
      }

      let memberId = null;

      if (role === 'Member') {
        memberId =
          await ensureMember(
            client,
            {
              name,
              email,

              memberId:
                requestedMemberId,
            },
          );
      }

      const passwordHash =
        await bcrypt.hash(
          password,
          12,
        );

      const result =
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
            $4,
            $5,
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
            name,
            email,
            passwordHash,
            role,
            memberId,
          ],
        );

      await client.query(
        'COMMIT',
      );

      return res.status(201).json({
        message:
          `${role} account created successfully`,

        user:
          result.rows[0],
      });
    } catch (error) {
      try {
        await client.query(
          'ROLLBACK',
        );
      } catch (_) {}

      console.error(
        'Create user error:',
        error,
      );

      return res.status(500).json({
        message:
          error.message ||
          'Failed to create user',
      });
    } finally {
      client.release();
    }
  },
);

// ============================================================
// UPDATE USER
// ============================================================

async function updateUser(
  req,
  res,
) {
  const client =
    await pool.connect();

  try {
    const id =
      Number(req.params.id);

    const old =
      await client.query(
        `
        SELECT *
        FROM users
        WHERE id = $1
        LIMIT 1
        `,
        [id],
      );

    if (!old.rows.length) {
      return res.status(404).json({
        message:
          'User not found',
      });
    }

    const current =
      old.rows[0];

    const name = String(
      req.body?.name ??
        current.name,
    ).trim();

    const email = String(
      req.body?.email ??
        current.email,
    )
      .trim()
      .toLowerCase();

    const role =
      normalizeRole(
        req.body?.role ??
          current.role,
      );

    if (!role) {
      return res.status(400).json({
        message:
          'Invalid role',
      });
    }

    const isActive =
      req.body?.isActive ===
          undefined &&
      req.body?.is_active ===
          undefined
        ? current.is_active
        : Boolean(
            req.body?.isActive ??
              req.body?.is_active,
          );

    await client.query(
      'BEGIN',
    );

    const duplicate =
      await client.query(
        `
        SELECT id
        FROM users
        WHERE
          LOWER(email)
            = LOWER($1)
          AND id <> $2
        LIMIT 1
        `,
        [
          email,
          id,
        ],
      );

    if (
      duplicate.rows.length
    ) {
      await client.query(
        'ROLLBACK',
      );

      return res.status(409).json({
        message:
          'Email already exists',
      });
    }

    let memberId =
      current.member_id;

    if (role === 'Member') {
      memberId =
        await ensureMember(
          client,
          {
            name,
            email,

            memberId:
              req.body?.memberId ??
              req.body?.member_id ??
              memberId,
          },
        );
    } else {
      memberId = null;
    }

    let passwordHash =
      current.password_hash;

    if (req.body?.password) {
      const newPassword =
        String(
          req.body.password,
        );

      if (
        newPassword.length < 6
      ) {
        await client.query(
          'ROLLBACK',
        );

        return res.status(400).json({
          message:
            'Password must have at least 6 characters',
        });
      }

      passwordHash =
        await bcrypt.hash(
          newPassword,
          12,
        );
    }

    const updated =
      await client.query(
        `
        UPDATE users
        SET
          name = $1,
          email = $2,
          password_hash = $3,
          role = $4,
          member_id = $5,
          is_active = $6
        WHERE id = $7
        RETURNING
          id,
          name,
          email,
          role,
          member_id,
          is_active
        `,
        [
          name,
          email,
          passwordHash,
          role,
          memberId,
          isActive,
          id,
        ],
      );

    await client.query(
      'COMMIT',
    );

    return res.json({
      message:
        'User updated successfully',

      user:
        updated.rows[0],
    });
  } catch (error) {
    try {
      await client.query(
        'ROLLBACK',
      );
    } catch (_) {}

    console.error(
      'Update user error:',
      error,
    );

    return res.status(500).json({
      message:
        error.message ||
        'Failed to update user',
    });
  } finally {
    client.release();
  }
}

router.put(
  '/:id',
  authenticateToken,
  adminOnly,
  updateUser,
);

router.patch(
  '/:id',
  authenticateToken,
  adminOnly,
  updateUser,
);

// ============================================================
// DELETE USER
// ============================================================

router.delete(
  '/:id',
  authenticateToken,
  adminOnly,
  async (req, res) => {
    try {
      const id =
        Number(req.params.id);

      const currentId =
        Number(
          req.user?.id ||
            req.user?.userId,
        );

      if (id === currentId) {
        return res.status(400).json({
          message:
            'You cannot delete the current account',
        });
      }

      const result =
        await pool.query(
          `
          DELETE FROM users
          WHERE id = $1
          RETURNING id
          `,
          [id],
        );

      if (!result.rows.length) {
        return res.status(404).json({
          message:
            'User not found',
        });
      }

      return res.json({
        message:
          'User deleted successfully',
      });
    } catch (error) {
      console.error(
        'Delete user error:',
        error,
      );

      return res.status(500).json({
        message:
          'Failed to delete user',
      });
    }
  },
);

module.exports = router;
