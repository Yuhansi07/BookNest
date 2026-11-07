function allowRoles(...roles) {
  const allowed = roles.map((r) => r.toLowerCase());

  return (req, res, next) => {
    const role = (req.user?.role || '').toLowerCase();

    if (!allowed.includes(role)) {
      return res.status(403).json({ message: 'You do not have permission for this action' });
    }

    next();
  };
}

module.exports = allowRoles;
