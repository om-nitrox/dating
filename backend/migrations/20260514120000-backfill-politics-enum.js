// Phase 1.5: backfill User.politics from legacy values to the OpenAPI spec enum.
/**
 * Pre-spec User documents stored `politics` as a free-form string with the
 * legacy taxonomy: ['left', 'center_left', 'center', 'center_right', 'right']
 * (still visible in `src/domain/taxonomies.js` as the POLITICS export).
 *
 * The OpenAPI spec (`docs/api/openapi.yaml`) instead defines:
 *   ['liberal', 'moderate', 'conservative', 'not_political', 'prefer_not_to_say']
 *
 * Mapping applied (idempotent):
 *   'left'          -> 'liberal'
 *   'center_left'   -> 'liberal'
 *   'center'        -> 'moderate'
 *   'center_right'  -> 'conservative'
 *   'right'         -> 'conservative'
 *   anything else / null / missing  -> 'prefer_not_to_say'
 *
 * Idempotency: each update is conditional on the source value so running the
 * migration twice is a no-op. The "anything else" step explicitly EXCLUDES
 * the canonical enum values so we don't re-tag already-correct rows.
 *
 * Reversibility: politics history cannot be reconstructed from the new value
 * (multiple legacy inputs map to the same canonical output). The `down`
 * function therefore throws — by design.
 */

const LEGACY_TO_CANONICAL = {
  left: 'liberal',
  center_left: 'liberal',
  center: 'moderate',
  center_right: 'conservative',
  right: 'conservative',
};

const CANONICAL_VALUES = [
  'liberal',
  'moderate',
  'conservative',
  'not_political',
  'prefer_not_to_say',
];

module.exports = {
  async up(db) {
    const users = db.collection('users');

    const summary = {};

    // Step 1: map each legacy value to its canonical equivalent.
    for (const [legacy, canonical] of Object.entries(LEGACY_TO_CANONICAL)) {
      // eslint-disable-next-line no-await-in-loop
      const res = await users.updateMany(
        { politics: legacy },
        { $set: { politics: canonical } },
      );
      summary[`${legacy} -> ${canonical}`] = res.modifiedCount;
    }

    // Step 2: anything still outside the canonical enum (free-form strings,
    // null, missing) becomes 'prefer_not_to_say'. Excludes rows already in
    // the canonical set so this is safe to re-run.
    const res = await users.updateMany(
      {
        $or: [
          { politics: { $exists: false } },
          { politics: null },
          { politics: '' },
          { politics: { $nin: CANONICAL_VALUES } },
        ],
      },
      { $set: { politics: 'prefer_not_to_say' } },
    );
    summary['fallback -> prefer_not_to_say'] = res.modifiedCount;

    // eslint-disable-next-line no-console
    console.log(JSON.stringify({
      migration: '20260514120000-backfill-politics-enum',
      event: 'migration.applied',
      summary,
    }));
  },

  async down() {
    // POLITICS is a destructive change: multiple legacy inputs collapse to
    // the same canonical output, so a generic reverse mapping is unsafe.
    // The brief explicitly opts out of a reversible down migration.
    throw new Error(
      'down() is intentionally not implemented for politics backfill (irreversible by design).',
    );
  },
};
