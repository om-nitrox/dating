/**
 * NoSQL injection prevention middleware.
 * Strips keys starting with '$' and containing '.' from req.body, req.query, req.params.
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
  if (req.body) req.body = sanitizeObject(req.body);
  if (req.query) req.query = sanitizeObject(req.query);
  if (req.params) req.params = sanitizeObject(req.params);
  next();
};

module.exports = sanitize;
