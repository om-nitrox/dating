// Phase 0.3: validator codegen.
/**
 * zod-based validation middleware.
 *
 * Adapts a zod schema (or a triple { body, query, params }) to the
 * `(req, res, next)` shape of the existing Joi `validate(...)` /
 * `validateQuery(...)` middleware. Route mounts keep their existing call
 * sites; only the schema source changes.
 *
 * Why both Joi and zod coexist in the codebase:
 *   The legacy validators are kept as a back-up because some of them
 *   (notably `profile.validator`) have hand-tuned Joi constructs (like
 *   the `ageMin <= ageMax` custom check) that the OpenAPI spec does not
 *   yet model. As we widen the spec, individual validators can flip from
 *   Joi to zod with no route changes.
 *
 * Error mapping:
 *   The existing global error middleware reads `AppError` instances with
 *   a 400 status and concatenates messages with a comma. We mirror that
 *   exactly so the error response shape stays stable from the frontend's
 *   point of view.
 */

const AppError = require('../utils/AppError');

/**
 * Format a zod ZodError into the `field: message; field: message` string
 * the existing Joi validator emits.
 */
const formatZodError = (err) => err.issues
  .map((issue) => {
    const pathStr = issue.path.length > 0 ? issue.path.join('.') : '(root)';
    return `${pathStr}: ${issue.message}`;
  })
  .join(', ');

/**
 * Validate one slice of the request (body / query / params) against a zod
 * schema. On success, write the parsed value back so downstream handlers
 * see the coerced shape (numbers, dates, etc.). Returns null on success
 * and an `AppError` on failure.
 *
 * `target` is the key on `req` to write the parsed value back to.
 *   - body   -> req.body + req.cleanBody
 *   - query  -> req.cleanQuery       (req.query is read-only in Express 5)
 *   - params -> req.params + req.cleanParams
 */
const validateOne = (req, schema, slice, target) => {
  // Read from the cleaned variant first (post-sanitize). Falls back to the
  // raw req.<slice> for tests that bypass the sanitize middleware.
  let source;
  if (slice === 'body') source = req.cleanBody ?? req.body ?? {};
  else if (slice === 'query') source = req.cleanQuery ?? req.query ?? {};
  else if (slice === 'params') source = req.cleanParams ?? req.params ?? {};
  else source = {};

  const result = schema.safeParse(source);
  if (!result.success) {
    return new AppError(formatZodError(result.error), 400);
  }
  // Write the coerced value back so handlers can read req.body.<key> with
  // the right type (e.g. a coerced number for `?page=2`).
  if (target === 'body') {
    req.body = result.data;
    req.cleanBody = result.data;
  } else if (target === 'query') {
    req.cleanQuery = result.data;
  } else if (target === 'params') {
    req.params = result.data;
    req.cleanParams = result.data;
  }
  return null;
};

/**
 * Build a middleware that validates one or more slices.
 *
 * Usage:
 *   zodValidate(requests.updateProfile)   // combination of body/query/params present on the operation
 *   zodValidate({ body: someSchema })     // single slice
 *   zodValidate(someBodyOnlySchema)       // a bare zod schema is treated as the body schema
 */
const zodValidate = (spec) => {
  // Accept a bare zod schema as the body schema.
  const isBareSchema = spec && typeof spec === 'object' && typeof spec.safeParse === 'function';
  const config = isBareSchema ? { body: spec } : spec || {};

  return (req, res, next) => {
    if (config.params) {
      const err = validateOne(req, config.params, 'params', 'params');
      if (err) return next(err);
    }
    if (config.query) {
      const err = validateOne(req, config.query, 'query', 'query');
      if (err) return next(err);
    }
    if (config.body) {
      const err = validateOne(req, config.body, 'body', 'body');
      if (err) return next(err);
    }
    return next();
  };
};

module.exports = { zodValidate, formatZodError };
