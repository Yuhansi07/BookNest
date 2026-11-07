const express = require('express');
const authenticateToken = require('../middleware/auth');

const router = express.Router();
const AI_URL = process.env.AI_SERVICE_URL || 'http://127.0.0.1:8000';


function currentRole(req) {
  return String(req.user?.role || '').trim().toLowerCase();
}

function allowAiRoles(...roles) {
  const allowed = roles.map((role) => role.toLowerCase());
  return (req, res, next) => {
    if (!allowed.includes(currentRole(req))) {
      return res.status(403).json({ message: 'This AI feature is not available for your role' });
    }
    next();
  };
}

async function aiFetch(path, options = {}) {
  let response;
  try {
    response = await fetch(`${AI_URL}${path}`, {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...(options.headers || {}),
      },
    });
  } catch (error) {
    const e = new Error('AI service is unavailable');
    e.status = 503;
    throw e;
  }

  const body = await response.text();
  let data;
  try { data = body ? JSON.parse(body) : null; } catch (_) { data = body; }

  if (!response.ok) {
    const e = new Error(data?.detail || data?.message || 'AI request failed');
    e.status = response.status;
    throw e;
  }
  return data;
}

router.get('/health', authenticateToken, async (req, res) => {
  try { res.json(await aiFetch('/health')); }
  catch (e) { res.status(e.status || 500).json({ message: e.message }); }
});

router.get('/recommendations/member/:id', authenticateToken, allowAiRoles('Librarian', 'Member'), async (req, res) => {
  try {
    const memberId = Number(req.params.id);
    if (currentRole(req) === 'member' && Number(req.user.memberId) !== memberId) {
      return res.status(403).json({ message: 'You can only view your own recommendations' });
    }
    res.json(await aiFetch(`/recommendations/member/${memberId}?limit=${Number(req.query.limit) || 6}`));
  } catch (e) { res.status(e.status || 500).json({ message: e.message }); }
});

router.get('/recommendations/member/:id/expanded', authenticateToken, allowAiRoles('Librarian', 'Member'), async (req, res) => {
  try {
    const memberId = Number(req.params.id);
    if (currentRole(req) === 'member' && Number(req.user.memberId) !== memberId) {
      return res.status(403).json({ message: 'You can only view your own recommendations' });
    }
    res.json(await aiFetch(`/recommendations/member/${memberId}/expanded?limit=${Number(req.query.limit) || 6}`));
  } catch (e) { res.status(e.status || 500).json({ message: e.message }); }
});

router.get('/similar-book/:id', authenticateToken, allowAiRoles('Librarian', 'Member'), async (req, res) => {
  try { res.json(await aiFetch(`/similar-books/${Number(req.params.id)}?limit=${Number(req.query.limit) || 5}`)); }
  catch (e) { res.status(e.status || 500).json({ message: e.message }); }
});

router.get('/member-risk/:id', authenticateToken, allowAiRoles('Librarian'), async (req, res) => {
  try {
    const memberId = Number(req.params.id);
    if ((req.user.role || '').toLowerCase() === 'member' && req.user.memberId !== memberId) {
      return res.status(403).json({ message: 'You can only view your own risk profile' });
    }
    res.json(await aiFetch(`/member-risk/${memberId}`));
  } catch (e) { res.status(e.status || 500).json({ message: e.message }); }
});

router.get('/demand-forecast', authenticateToken, allowAiRoles('Librarian'), async (req, res) => {
  try { res.json(await aiFetch(`/demand-forecast?months=${Number(req.query.months) || 6}&limit=${Number(req.query.limit) || 8}`)); }
  catch (e) { res.status(e.status || 500).json({ message: e.message }); }
});

router.get('/anomalies', authenticateToken, allowAiRoles('Librarian'), async (req, res) => {
  try { res.json(await aiFetch(`/anomalies?limit=${Number(req.query.limit) || 8}`)); }
  catch (e) { res.status(e.status || 500).json({ message: e.message }); }
});

router.post('/search', authenticateToken, allowAiRoles('Librarian', 'Member'), async (req, res) => {
  try {
    res.json(await aiFetch('/search', { method: 'POST', body: JSON.stringify(req.body || {}) }));
  } catch (e) { res.status(e.status || 500).json({ message: e.message }); }
});


// ============================================================
// AI CHAT ASSISTANT
// POST /api/ai/chat
// The authenticated user's role/member identity is injected here
// so the Python service never trusts role data from the browser.
// ============================================================
router.post('/chat', authenticateToken, allowAiRoles('Librarian', 'Member'), async (req, res) => {
  try {
    const message = String(req.body?.message || '').trim();

    if (!message) {
      return res.status(400).json({ message: 'Message is required' });
    }

    if (message.length > 1200) {
      return res.status(400).json({ message: 'Message is too long' });
    }

    const payload = {
      message,
      role: req.user?.role || '',
      member_id: req.user?.memberId || null,
      user_name: req.user?.name || '',
    };

    const data = await aiFetch('/chat', {
      method: 'POST',
      body: JSON.stringify(payload),
    });

    res.json(data);
  } catch (e) {
    res.status(e.status || 500).json({ message: e.message });
  }
});

module.exports = router;
