
require('dotenv').config();

const express =
  require('express');

const cors =
  require('cors');

const pool =
  require('./db');

const authRoutes =
  require('./routes/auth');

const bookRoutes =
  require('./routes/books');

const memberRoutes =
  require('./routes/members');

const loanRoutes =
  require('./routes/loans');

const dashboardRoutes =
  require('./routes/dashboard');

const userRoutes =
  require('./routes/users');

const profileRoutes =
  require('./routes/profile');

const reservationRoutes =
  require('./routes/reservations');

const reportRoutes =
  require('./routes/reports');

const categoryRoutes =
  require('./routes/categories');

const auditRoutes =
  require('./routes/audit');

const aiRoutes =
  require('./routes/ai');

const notificationRoutes =
  require('./routes/notifications');

const registrationRequestRoutes =
  require('./routes/registration-requests');

const preferenceRoutes =
  require('./routes/preferences');

const reviewRoutes = require('./routes/reviews');

const app =
  express();

// ============================================================
// MIDDLEWARE
// ============================================================

app.use(
  cors({
    origin: true,
    credentials: true,
  }),
);

app.use(
  express.json({
    limit: '2mb',
  }),
);

// ============================================================
// ROOT
// ============================================================

app.get(
  '/',
  (req, res) => {
    return res.json({
      name:
        'Library Management System API',

      version:
        '3.1-public-registration',

      status:
        'running',

      aiService:
        process.env.AI_SERVICE_URL ||
        'http://127.0.0.1:8000',
    });
  },
);

// ============================================================
// HEALTH
// ============================================================

app.get(
  '/health',
  async (req, res) => {
    try {
      const result =
        await pool.query(
          'SELECT NOW()',
        );

      return res.json({
        status:
          'ok',

        database:
          'PostgreSQL',

        databaseName:
          process.env.DB_NAME,

        serverTime:
          result.rows[0].now,
      });
    } catch (error) {
      console.error(
        'Health check error:',
        error,
      );

      return res.status(500).json({
        status:
          'error',

        message:
          'Database connection failed',
      });
    }
  },
);

// ============================================================
// ROUTES
// ============================================================

app.use(
  '/api/auth',
  authRoutes,
);

app.use(
  '/api/books',
  bookRoutes,
);

app.use(
  '/api/members',
  memberRoutes,
);

app.use(
  '/api/loans',
  loanRoutes,
);

app.use(
  '/api/dashboard',
  dashboardRoutes,
);

app.use(
  '/api/users',
  userRoutes,
);

app.use(
  '/api/profile',
  profileRoutes,
);

app.use(
  '/api/reservations',
  reservationRoutes,
);

app.use(
  '/api/reports',
  reportRoutes,
);

app.use(
  '/api/categories',
  categoryRoutes,
);

app.use(
  '/api/audit',
  auditRoutes,
);

app.use(
  '/api/ai',
  aiRoutes,
);

app.use(
  '/api/notifications',
  notificationRoutes,
);

app.use(
  '/api/registration-requests',
  registrationRequestRoutes,
);

app.use(
  '/api/preferences',
  preferenceRoutes,
);


app.use('/api/reviews', reviewRoutes);

// ============================================================
// 404
// ============================================================

app.use(
  (req, res) => {
    return res.status(404).json({
      message:
        'Route not found',
    });
  },
);

// ============================================================
// ERROR HANDLER
// ============================================================

app.use(
  (
    err,
    req,
    res,
    next,
  ) => {
    console.error(
      'Unhandled server error:',
      err,
    );

    return res.status(500).json({
      message:
        'Internal server error',
    });
  },
);

// ============================================================
// START SERVER
// ============================================================

const PORT =
  process.env.PORT ||
  5000;

app.listen(
  PORT,
  () => {
    console.log(
      `Library API running on http://localhost:${PORT}`,
    );

    console.log(
      'Library Management System API v3.1 Public Registration',
    );

    console.log(
      `AI Service URL: ${
        process.env.AI_SERVICE_URL ||
        'http://127.0.0.1:8000'
      }`,
    );
  },
);
