const express = require('express');
const ExcelJS = require('exceljs');
const PDFDocument = require('pdfkit');
const pool = require('../db');
const authenticateToken = require('../middleware/auth');
const allowRoles = require('../middleware/roles');

const router = express.Router();

function authenticateDownload(req, res, next) {
  const queryToken = String(req.query.token || '').trim();
  if (!req.headers.authorization && queryToken) {
    req.headers.authorization = `Bearer ${queryToken}`;
  }
  return authenticateToken(req, res, next);
}

function normalizeRange(req) {
  const today = new Date();
  const to = String(req.query.to || today.toISOString().slice(0, 10));
  const fallbackFrom = new Date(`${to}T00:00:00`);
  if (Number.isNaN(fallbackFrom.getTime())) {
    throw new Error('Invalid report date range');
  }
  fallbackFrom.setMonth(fallbackFrom.getMonth() - 6);
  const from = String(req.query.from || fallbackFrom.toISOString().slice(0, 10));
  return { from, to };
}

router.get('/summary', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        (SELECT COUNT(*) FROM books)::int AS books,
        (SELECT COUNT(*) FROM members)::int AS members,
        (SELECT COUNT(*) FROM loans)::int AS total_loans,
        (SELECT COUNT(*) FROM loans WHERE status='Issued')::int AS issued,
        (SELECT COUNT(*) FROM loans WHERE status='Issued' AND due_date::date < CURRENT_DATE)::int AS overdue,
        (SELECT COALESCE(SUM(fine),0) FROM loans WHERE COALESCE(fine_paid,false)=false)::numeric(12,2) AS unpaid_fines
    `);
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Report summary error:', error);
    res.status(500).json({ message: 'Failed to get report summary' });
  }
});

router.get('/overdue', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT l.id, b.title, b.isbn, m.member_code, m.name AS member_name,
             l.issue_date, l.due_date,
             (CURRENT_DATE-l.due_date::date)::int AS overdue_days,
             ((CURRENT_DATE-l.due_date::date) * $1::numeric) AS calculated_fine
      FROM loans l
      JOIN books b ON b.id=l.book_id
      JOIN members m ON m.id=l.member_id
      WHERE l.status='Issued' AND l.due_date::date < CURRENT_DATE
      ORDER BY overdue_days DESC
    `, [Number(process.env.FINE_PER_DAY) || 50]);
    res.json(result.rows);
  } catch (error) {
    console.error('Overdue report error:', error);
    res.status(500).json({ message: 'Failed to get overdue loans' });
  }
});

router.get('/popular-books', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT b.id, b.title, b.author, b.category, COUNT(l.id)::int AS borrow_count
      FROM books b
      LEFT JOIN loans l ON l.book_id=b.id
      GROUP BY b.id
      ORDER BY borrow_count DESC, b.title ASC
      LIMIT 10
    `);
    res.json(result.rows);
  } catch (error) {
    console.error('Popular books error:', error);
    res.status(500).json({ message: 'Failed to get popular books' });
  }
});

router.get('/member/:id', authenticateToken, async (req, res) => {
  try {
    const id = Number(req.params.id);
    if ((req.user.role || '').toLowerCase() === 'member' && Number(req.user.memberId) !== id) {
      return res.status(403).json({ message: 'You can only view your own history' });
    }
    const result = await pool.query(`
      SELECT b.title, b.isbn, l.issue_date, l.due_date, l.return_date, l.status, l.fine, l.fine_paid
      FROM loans l JOIN books b ON b.id=l.book_id
      WHERE l.member_id=$1 ORDER BY l.issue_date DESC
    `, [id]);
    res.json(result.rows);
  } catch (error) {
    console.error('Member history error:', error);
    res.status(500).json({ message: 'Failed to load member history' });
  }
});

router.get('/analytics', authenticateToken, allowRoles('Admin', 'Librarian'), async (req, res) => {
  try {
    const { from, to } = normalizeRange(req);
    const [monthly, popular, members, categories, fines, overdueTrend] = await Promise.all([
      pool.query(`
        SELECT TO_CHAR(date_trunc('month', issue_date), 'YYYY-MM') AS month,
               COUNT(*)::int AS loans
        FROM loans
        WHERE issue_date::date BETWEEN $1 AND $2
        GROUP BY date_trunc('month', issue_date)
        ORDER BY date_trunc('month', issue_date)
      `, [from, to]),
      pool.query(`
        SELECT b.title, b.author, COUNT(l.id)::int AS borrow_count
        FROM loans l JOIN books b ON b.id=l.book_id
        WHERE l.issue_date::date BETWEEN $1 AND $2
        GROUP BY b.id
        ORDER BY borrow_count DESC
        LIMIT 10
      `, [from, to]),
      pool.query(`
        SELECT m.member_code, m.name, COUNT(l.id)::int AS loan_count,
               COALESCE(SUM(l.fine),0)::numeric(12,2) AS fines
        FROM members m LEFT JOIN loans l ON l.member_id=m.id
          AND l.issue_date::date BETWEEN $1 AND $2
        GROUP BY m.id
        ORDER BY loan_count DESC, m.name
        LIMIT 10
      `, [from, to]),
      pool.query(`
        SELECT COALESCE(NULLIF(b.category,''),'Uncategorized') AS category,
               COUNT(l.id)::int AS borrow_count
        FROM books b LEFT JOIN loans l ON l.book_id=b.id
          AND l.issue_date::date BETWEEN $1 AND $2
        GROUP BY COALESCE(NULLIF(b.category,''),'Uncategorized')
        ORDER BY borrow_count DESC
      `, [from, to]),
      pool.query(`
        SELECT
          COALESCE(SUM(fine),0)::numeric(12,2) AS total_assessed,
          COALESCE(SUM(fine) FILTER (WHERE fine_paid=true),0)::numeric(12,2) AS total_paid,
          COALESCE(SUM(fine) FILTER (WHERE fine_paid=false),0)::numeric(12,2) AS total_unpaid
        FROM loans
        WHERE issue_date::date BETWEEN $1 AND $2
      `, [from, to]),
      pool.query(`
        SELECT TO_CHAR(date_trunc('month', due_date), 'YYYY-MM') AS month,
               COUNT(*) FILTER (
                 WHERE (return_date IS NULL AND due_date::date < CURRENT_DATE)
                    OR (return_date IS NOT NULL AND return_date::date > due_date::date)
               )::int AS overdue_count
        FROM loans
        WHERE due_date::date BETWEEN $1 AND $2
        GROUP BY date_trunc('month', due_date)
        ORDER BY date_trunc('month', due_date)
      `, [from, to]),
    ]);

    res.json({
      from,
      to,
      monthlyLoans: monthly.rows,
      popularBooks: popular.rows,
      activeMembers: members.rows,
      categoryPopularity: categories.rows,
      fineCollection: fines.rows[0],
      overdueTrend: overdueTrend.rows,
    });
  } catch (error) {
    console.error('Analytics report error:', error);
    res.status(500).json({ message: 'Failed to load analytics' });
  }
});

async function getExportData(from, to) {
  const result = await pool.query(`
    SELECT
      l.id AS loan_id,
      b.isbn,
      b.title,
      b.author,
      COALESCE(b.category, '') AS category,
      m.member_code,
      m.name AS member_name,
      l.issue_date,
      l.due_date,
      l.return_date,
      l.status,
      COALESCE(l.fine,0)::numeric(12,2) AS fine,
      COALESCE(l.fine_paid,false) AS fine_paid
    FROM loans l
    JOIN books b ON b.id=l.book_id
    JOIN members m ON m.id=l.member_id
    WHERE l.issue_date::date BETWEEN $1 AND $2
    ORDER BY l.issue_date DESC, l.id DESC
  `, [from, to]);
  return result.rows;
}

router.get('/export.xlsx', authenticateDownload, allowRoles('Admin', 'Librarian'), async (req, res) => {
  try {
    const { from, to } = normalizeRange(req);
    const rows = await getExportData(from, to);

    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'Library Management System';
    workbook.created = new Date();

    const sheet = workbook.addWorksheet('Loan Report', {
      views: [{ state: 'frozen', ySplit: 1 }],
    });

    sheet.columns = [
      { header: 'Loan ID', key: 'loan_id', width: 10 },
      { header: 'ISBN', key: 'isbn', width: 18 },
      { header: 'Title', key: 'title', width: 32 },
      { header: 'Author', key: 'author', width: 24 },
      { header: 'Category', key: 'category', width: 20 },
      { header: 'Member Code', key: 'member_code', width: 16 },
      { header: 'Member', key: 'member_name', width: 24 },
      { header: 'Issue Date', key: 'issue_date', width: 20 },
      { header: 'Due Date', key: 'due_date', width: 20 },
      { header: 'Return Date', key: 'return_date', width: 20 },
      { header: 'Status', key: 'status', width: 14 },
      { header: 'Fine (LKR)', key: 'fine', width: 14 },
      { header: 'Fine Paid', key: 'fine_paid', width: 12 },
    ];

    rows.forEach((row) => sheet.addRow(row));
    sheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFFFF' } };
    sheet.getRow(1).fill = {
      type: 'pattern',
      pattern: 'solid',
      fgColor: { argb: 'FF5B50D6' },
    };
    sheet.autoFilter = { from: 'A1', to: 'M1' };

    const buffer = await workbook.xlsx.writeBuffer();
    res.status(200);
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    res.setHeader('Content-Disposition', `attachment; filename="library-report-${from}-${to}.xlsx"`);
    res.setHeader('Content-Length', buffer.length);
    return res.end(buffer);
  } catch (error) {
    console.error('Excel export error:', error);
    if (!res.headersSent) {
      return res.status(500).json({ message: `Failed to export Excel report: ${error.message}` });
    }
  }
});

router.get('/export.pdf', authenticateDownload, allowRoles('Admin', 'Librarian'), async (req, res) => {
  try {
    const { from, to } = normalizeRange(req);
    const rows = await getExportData(from, to);

    res.status(200);
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename="library-report-${from}-${to}.pdf"`);

    const doc = new PDFDocument({ margin: 42, size: 'A4' });
    doc.pipe(res);

    doc.fontSize(19).fillColor('#151826').text('Library Management System');
    doc.moveDown(0.2).fontSize(13).fillColor('#5B50D6').text('Loan Activity Report');
    doc.moveDown(0.15).fontSize(9).fillColor('#6B7280').text(`Period: ${from} to ${to}`);
    doc.moveDown(1);

    if (!rows.length) {
      doc.fontSize(11).fillColor('#334155').text('No loan records were found for the selected period.');
    } else {
      rows.forEach((row, index) => {
        if (doc.y > 730) doc.addPage();
        doc.fontSize(10).fillColor('#151826').text(`${index + 1}. ${row.title || '-'}${row.isbn ? ` (${row.isbn})` : ''}`);
        doc.fontSize(8).fillColor('#64748B').text(
          `${row.member_code || '-'} - ${row.member_name || '-'}  |  Issued: ${row.issue_date ? new Date(row.issue_date).toLocaleDateString('en-GB') : '-'}  |  Due: ${row.due_date ? new Date(row.due_date).toLocaleDateString('en-GB') : '-'}  |  Status: ${row.status || '-'}  |  Fine: LKR ${Number(row.fine || 0).toFixed(2)}`,
          { width: 510 },
        );
        doc.moveDown(0.7);
      });
    }

    doc.end();
  } catch (error) {
    console.error('PDF export error:', error);
    if (!res.headersSent) {
      return res.status(500).json({ message: `Failed to export PDF report: ${error.message}` });
    }
  }
});

module.exports = router;
