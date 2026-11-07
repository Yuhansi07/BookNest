require('dotenv').config();

const pool = require('./db');

const broadCategories = new Set([
  'technology & computing',
  'science & engineering',
  'business & management',
  'history & politics',
  'biography & memoir',
  'self-development',
  'health & lifestyle',
  'fiction / novels',
  'mystery & thriller',
  'romance',
  'science fiction & fantasy',
  'children & young adult',
  'travel & culture',
  'general / other',
]);

function broadCategory(category) {
  const raw =
    String(category || '').trim();

  const value =
    raw.toLowerCase();

  if (
    broadCategories.has(value)
  ) {
    return raw;
  }

  const technology = [
    'programming',
    'database',
    'artificial intelligence',
    'machine learning',
    'ai',
    'cloud',
    'communication',
    'computer science',
    'cyber',
    'data science',
    'network',
    'devops',
    'software',
    'web',
    'iot',
    'information technology',
  ];

  if (
    technology.some(
      (x) => value.includes(x),
    )
  ) {
    return 'Technology & Computing';
  }

  const engineering = [
    'electronics',
    'embedded',
    'fpga',
    'mathematics',
    'physics',
    'engineering',
    'robotics',
    'control',
    'signal',
    'electrical',
  ];

  if (
    engineering.some(
      (x) => value.includes(x),
    )
  ) {
    return 'Science & Engineering';
  }

  if (
    value.includes('business') ||
    value.includes('management') ||
    value.includes('finance') ||
    value.includes('economic')
  ) {
    return 'Business & Management';
  }

  if (
    value.includes('history') ||
    value.includes('politic')
  ) {
    return 'History & Politics';
  }

  if (
    value.includes('biography') ||
    value.includes('memoir')
  ) {
    return 'Biography & Memoir';
  }

  if (
    value.includes('self') ||
    value.includes('personal development')
  ) {
    return 'Self-development';
  }

  if (
    value.includes('health') ||
    value.includes('lifestyle') ||
    value.includes('wellness')
  ) {
    return 'Health & Lifestyle';
  }

  if (
    value.includes('mystery') ||
    value.includes('thriller')
  ) {
    return 'Mystery & Thriller';
  }

  if (
    value.includes('romance')
  ) {
    return 'Romance';
  }

  if (
    value.includes('science fiction') ||
    value.includes('sci-fi') ||
    value.includes('fantasy')
  ) {
    return 'Science Fiction & Fantasy';
  }

  if (
    value.includes('children') ||
    value.includes('young adult')
  ) {
    return 'Children & Young Adult';
  }

  if (
    value.includes('travel') ||
    value.includes('culture')
  ) {
    return 'Travel & Culture';
  }

  if (
    value.includes('fiction') ||
    value.includes('novel')
  ) {
    return 'Fiction / Novels';
  }

  return 'General / Other';
}

async function main() {
  await pool.query(`
    ALTER TABLE books
    ADD COLUMN IF NOT EXISTS
      tags TEXT[] NOT NULL
      DEFAULT '{}'
  `);

  const result =
    await pool.query(
      `SELECT
         id,
         category,
         tags
       FROM books
       ORDER BY id`,
    );

  let updated = 0;

  for (const book of result.rows) {
    const oldCategory =
      String(
        book.category || '',
      ).trim();

    const nextCategory =
      broadCategory(
        oldCategory,
      );

    const tags =
      Array.isArray(book.tags)
        ? [...book.tags]
        : [];

    if (
      oldCategory &&
      oldCategory.toLowerCase() !==
        nextCategory.toLowerCase() &&
      !tags.includes(oldCategory)
    ) {
      tags.push(oldCategory);
    }

    await pool.query(
      `
      UPDATE books
      SET
        category=$1,
        tags=$2
      WHERE id=$3
      `,
      [
        nextCategory,
        tags,
        book.id,
      ],
    );

    updated++;
  }

  console.log(
    `Normalised ${updated} books into broad library categories.`,
  );

  await pool.end();
}

main().catch(
  async (error) => {
    console.error(error);

    try {
      await pool.end();
    } catch (_) {}

    process.exit(1);
  },
);
