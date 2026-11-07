const express = require('express');
const bcrypt = require('bcryptjs');
const pool = require('../db');
const authenticateToken = require('../middleware/auth');
const writeAudit = require('../services/audit');

const router = express.Router();

router.get('/', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id,name,email,role,member_id FROM users WHERE id=$1`,
      [req.user.id],
    );
    if (!result.rows[0]) return res.status(404).json({ message: 'User not found' });
    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ message: 'Failed to load profile' });
  }
});

router.put('/', authenticateToken, async (req, res) => {
  try {
    const { name, email } = req.body;
    if (!name || !email) return res.status(400).json({ message: 'Name and email are required' });
    const result = await pool.query(
      `UPDATE users SET name=$1,email=$2,updated_at=CURRENT_TIMESTAMP
       WHERE id=$3 RETURNING id,name,email,role,member_id`,
      [name.trim(), email.trim().toLowerCase(), req.user.id],
    );
    await writeAudit({ userId: req.user.id, action: 'PROFILE_UPDATED', entityType: 'User', entityId: req.user.id });
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Profile update error:', error);
    res.status(500).json({ message: 'Failed to update profile' });
  }
});

router.put('/password', authenticateToken, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword || newPassword.length < 6) {
      return res.status(400).json({ message: 'Current password and new password (6+ characters) are required' });
    }
    const result = await pool.query('SELECT password_hash FROM users WHERE id=$1', [req.user.id]);
    if (!result.rows[0]) return res.status(404).json({ message: 'User not found' });
    const ok = await bcrypt.compare(currentPassword, result.rows[0].password_hash);
    if (!ok) return res.status(400).json({ message: 'Current password is incorrect' });
    const hash = await bcrypt.hash(newPassword, 12);
    await pool.query('UPDATE users SET password_hash=$1,updated_at=CURRENT_TIMESTAMP WHERE id=$2', [hash, req.user.id]);
    await writeAudit({ userId: req.user.id, action: 'PASSWORD_CHANGED', entityType: 'User', entityId: req.user.id });
    res.json({ message: 'Password changed successfully' });
  } catch (error) {
    console.error('Password change error:', error);
    res.status(500).json({ message: 'Failed to change password' });
  }
});

module.exports = router;
