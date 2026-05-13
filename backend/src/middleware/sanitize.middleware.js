/**
 * NoSQL injection prevention middleware.
 *
 * Strips MongoDB operator keys (anything starting with `$`) from `req.body`,
 * `req.query`, and `req.params`. In Express 5, `req.query` is a getter and
 * cannot be reassigned — assignment is silently dropped. We therefore expose
 * cleaned copies under `req.cleanQuery` / `req.cleanBody` / `req.cleanParams`,
 * AND in-place clean `req.body` / `req.params` (which remain writable).
 *
 * Controllers/validators that read query params MUST read from
 * `req.cleanQuery` (not `req.query`).
 */

const sanitizeObject = (obj) => {
  if (obj === null || typeof obj !== 'object') return obj;

  if (Array.isArray(obj)) {
    return obj.map(sanitizeObject);
  }

  const clean = {};
  for (const [key, value] of Object.entries(obj)) {
    // Block MongoDB operators like $gt, $ne, $where, etc.
    if (key.startsWith('$')) continue;

    clean[key] = sanitizeObject(value);
  }
  return clean;
};

const sanitize = (req, res, next) => {
  // req.body and req.params remain assignable in Express 5.
  if (req.body) req.body = sanitizeObject(req.body);
  if (req.params) req.params = sanitizeObject(req.params);

  // req.query is read-only in Express 5 — expose the cleaned copy separately.
  req.cleanQuery = req.query ? sanitizeObject(req.query) : {};
  req.cleanBody = req.body || {};
  req.cleanParams = req.params || {};

  next();
};

module.exports = sanitize;
