const express = require('express');
const pool = require('../db');
const authenticateToken = require('../middleware/auth');

const router = express.Router();

async function ensureTable() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS member_reading_preferences_v2 (
      member_id INTEGER PRIMARY KEY
        REFERENCES members(id)
        ON DELETE CASCADE,

      preferred_categories JSONB NOT NULL DEFAULT '[]'::jsonb,
      reading_level VARCHAR(40),
      reading_goal VARCHAR(120),
      reading_style VARCHAR(120),
      onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,

      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    )
  `);
}

function memberId(req) {
  const value =
    req.user?.memberId ??
    req.user?.member_id ??
    null;

  const id = Number(value);

  return Number.isFinite(id) && id > 0
    ? id
    : null;
}

router.get(
  '/me',
  authenticateToken,
  async (req, res) => {
    try {
      const id = memberId(req);

      if (!id) {
        return res.status(403).json({
          message: 'Member account required',
        });
      }

      await ensureTable();

      const result = await pool.query(
        `SELECT *
         FROM member_reading_preferences_v2
         WHERE member_id=$1`,
        [id],
      );

      if (!result.rows.length) {
        return res.json({
          categories: [],
          readingLevel: 'Any',
          readingGoal: 'Explore new topics',
          readingStyle: 'Mixed',
          onboardingCompleted: false,
        });
      }

      const row = result.rows[0];

      return res.json({
        categories:
          Array.isArray(row.preferred_categories)
            ? row.preferred_categories
            : [],

        readingLevel:
          row.reading_level || 'Any',

        readingGoal:
          row.reading_goal ||
          'Explore new topics',

        readingStyle:
          row.reading_style || 'Mixed',

        onboardingCompleted:
          row.onboarding_completed === true,
      });
    } catch (error) {
      console.error(
        'Get reading preferences error:',
        error,
      );

      return res.status(500).json({
        message:
          'Failed to load reading preferences',
      });
    }
  },
);

router.put(
  '/me',
  authenticateToken,
  async (req, res) => {
    try {
      const id = memberId(req);

      if (!id) {
        return res.status(403).json({
          message: 'Member account required',
        });
      }

      await ensureTable();

      const categories =
        Array.isArray(req.body?.categories)
          ? req.body.categories
              .map((x) =>
                String(x || '').trim(),
              )
              .filter(Boolean)
          : [];

      const readingLevel = String(
        req.body?.readingLevel || 'Any',
      ).trim();

      const readingGoal = String(
        req.body?.readingGoal ||
          'Explore new topics',
      ).trim();

      const readingStyle = String(
        req.body?.readingStyle || 'Mixed',
      ).trim();

      const completed =
        req.body?.onboardingCompleted !== false;

      const result = await pool.query(
        `INSERT INTO member_reading_preferences_v2
         (
           member_id,
           preferred_categories,
           reading_level,
           reading_goal,
           reading_style,
           onboarding_completed,
           updated_at
         )
         VALUES
         ($1,$2::jsonb,$3,$4,$5,$6,CURRENT_TIMESTAMP)

         ON CONFLICT (member_id)
         DO UPDATE SET
           preferred_categories =
             EXCLUDED.preferred_categories,
           reading_level =
             EXCLUDED.reading_level,
           reading_goal =
             EXCLUDED.reading_goal,
           reading_style =
             EXCLUDED.reading_style,
           onboarding_completed =
             EXCLUDED.onboarding_completed,
           updated_at =
             CURRENT_TIMESTAMP

         RETURNING *`,
        [
          id,
          JSON.stringify(categories),
          readingLevel,
          readingGoal,
          readingStyle,
          completed,
        ],
      );

      return res.json({
        message:
          'Reading profile saved successfully',
        preferences: result.rows[0],
      });
    } catch (error) {
      console.error(
        'Save reading preferences error:',
        error,
      );

      return res.status(500).json({
        message:
          'Failed to save reading preferences',
      });
    }
  },
);

const aliases = {
  'Technology & Computing': [
    'technology & computing',
    'programming',
    'database',
    'artificial intelligence',
    'ai',
    'machine learning',
    'cloud computing',
    'communication',
    'computer science',
    'cybersecurity',
    'data science',
    'networking',
    'devops',
    'software engineering',
    'web development',
    'iot',
  ],

  'Science & Engineering': [
    'science & engineering',
    'electronics',
    'embedded systems',
    'fpga',
    'mathematics',
    'physics',
    'engineering',
    'electrical engineering',
    'robotics',
    'control systems',
    'signal processing',
  ],

  'Business & Management': [
    'business & management',
    'business',
    'management',
    'finance',
    'economics',
  ],

  'History & Politics': [
    'history & politics',
    'history',
    'politics',
  ],

  'Biography & Memoir': [
    'biography & memoir',
    'biography',
    'memoir',
  ],

  'Self-development': [
    'self-development',
    'self development',
    'self help',
    'personal development',
  ],

  'Health & Lifestyle': [
    'health & lifestyle',
    'health',
    'lifestyle',
    'wellness',
  ],

  'Fiction / Novels': [
    'fiction / novels',
    'fiction',
    'novel',
    'novels',
  ],

  'Mystery & Thriller': [
    'mystery & thriller',
    'mystery',
    'thriller',
  ],

  'Romance': [
    'romance',
  ],

  'Science Fiction & Fantasy': [
    'science fiction & fantasy',
    'science fiction',
    'sci-fi',
    'fantasy',
  ],

  'Children & Young Adult': [
    'children & young adult',
    'children',
    'young adult',
  ],

  'Travel & Culture': [
    'travel & culture',
    'travel',
    'culture',
  ],

  'General / Other': [
    'general / other',
    'general',
    'other',
  ],
};

router.get(
  '/recommendations',
  authenticateToken,
  async (req, res) => {
    try {
      const id = memberId(req);

      if (!id) {
        return res.status(403).json({
          message: 'Member account required',
        });
      }

      await ensureTable();

      const requestedLimit =
        Number(req.query.limit || 8);

      const limit = Math.max(
        1,
        Math.min(
          Number.isFinite(requestedLimit)
            ? requestedLimit
            : 8,
          20,
        ),
      );

      const prefResult =
        await pool.query(
          `SELECT preferred_categories
           FROM member_reading_preferences_v2
           WHERE member_id=$1`,
          [id],
        );

      const preferred =
        Array.isArray(
          prefResult.rows[0]
            ?.preferred_categories,
        )
          ? prefResult.rows[0]
              .preferred_categories
          : [];

      const booksResult =
        await pool.query(`
          SELECT *
          FROM books
          ORDER BY id
        `);

      const normalize = (value) =>
        String(value || '')
          .trim()
          .toLowerCase();

      const wanted = new Set();

      for (const category of preferred) {
        const values =
          aliases[category] || [category];

        for (const value of values) {
          wanted.add(normalize(value));
        }
      }

      const ranked =
        booksResult.rows.map((book) => {
          const category =
            normalize(book.category);

          let score = 0;

          if (wanted.has(category)) {
            score += 100;
          }

          if (
            Number(book.available_copies || 0) >
            0
          ) {
            score += 25;
          }

          score += Math.min(
            Number(
              book.available_copies || 0,
            ),
            10,
          );

          return {
            ...book,
            _score: score,

            reason:
              wanted.has(category)
                ? 'Matches your reading interests'
                : 'Available in the library',
          };
        });

      ranked.sort(
        (a, b) =>
          b._score - a._score,
      );

      const recommendations =
        ranked
          .filter(
            (book) =>
              Number(
                book.available_copies || 0,
              ) > 0,
          )
          .slice(0, limit)
          .map(
            ({
              _score,
              ...book
            }) => book,
          );

      return res.json({
        method: preferred.length
          ? 'reading_profile'
          : 'availability',

        preferred_categories:
          preferred,

        recommendations,
      });
    } catch (error) {
      console.error(
        'Reading recommendation error:',
        error,
      );

      return res.status(500).json({
        message:
          'Failed to create recommendations',
      });
    }
  },
);

module.exports = router;
