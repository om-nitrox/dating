/**
 * Single source of truth for all domain taxonomies (enums / controlled
 * vocabularies) used across the backend.
 *
 * Why a single module:
 *   - The same lists were previously duplicated across `models/User.js`,
 *     `validators/profile.validator.js`, `services/idealMatch.service.js`,
 *     `models/Report.js`, `validators/safety.validator.js`, and `validators/
 *     boost.validator.js`. Drift between copies risks the model accepting a
 *     value the validator rejects (or vice versa).
 *   - These arrays are also consumed by the OpenAPI spec (item 0.1) and by
 *     the Flutter client (via generated types). Keeping one canonical export
 *     makes future code generation straightforward.
 *
 * Conventions:
 *   - Every export is a frozen Array (Object.freeze) so a consumer cannot
 *     accidentally `push()` and mutate everyone else's view.
 *   - When the same taxonomy appeared under different names in different
 *     places, the MOST PERMISSIVE set wins so existing data is never
 *     invalidated by the consolidation. Mismatches are documented inline.
 */

const freeze = (arr) => Object.freeze([...arr]);

// -------- Identity --------
const GENDER = freeze(['male', 'female', 'nonbinary']);
const GENDER_PREFERENCE = freeze(['men', 'women', 'everyone']);
const ORIENTATION = freeze([
  // Free-form on the client (validator only enforces length / max 3) — listing
  // the common values here so a future OpenAPI schema can surface them as
  // suggestions, but the validator MUST NOT use this list as a closed enum.
  'straight',
  'gay',
  'lesbian',
  'bisexual',
  'pansexual',
  'asexual',
  'queer',
  'questioning',
  'other',
]);
const PRONOUNS = freeze([
  'he/him',
  'she/her',
  'they/them',
  'he/they',
  'she/they',
  'other',
]);

// -------- Profile content --------
const EXERCISE = freeze(['active', 'sometimes', 'never', 'prefer_not_to_say']);
const ZODIAC = freeze([
  'aries', 'taurus', 'gemini', 'cancer', 'leo', 'virgo',
  'libra', 'scorpio', 'sagittarius', 'capricorn', 'aquarius', 'pisces',
]);

// -------- Vitals / family --------
const CHILDREN = freeze(['have', 'dont_have', 'prefer_not_to_say']);
const FAMILY_PLANS = freeze([
  'want',
  'dont_want',
  'open',
  'not_sure',
  'prefer_not_to_say',
]);

// -------- Virtues --------
const DATING_INTENTIONS = freeze([
  'life_partner',
  'long_term',
  'long_term_open_short',
  'short_term_open_long',
  'short_term',
  'new_friends',
  'figuring_out',
]);
const RELATIONSHIP_TYPE = freeze([
  'monogamy',
  'non_monogamy',
  'open_to_exploring',
  'prefer_not_to_say',
]);

// Religion — the User model stores this as a free-form string (max 40 chars).
// The ideal-match service one-hot-encodes against a closed top-N list. We
// expose BOTH so each consumer can pick the right shape, and the closed list
// is the MOST PERMISSIVE existing variant (top-8 plus 'Other').
const RELIGION = freeze([
  'Hindu',
  'Muslim',
  'Christian',
  'Jewish',
  'Buddhist',
  'Sikh',
  'Atheist',
  'Spiritual',
  'Other',
]);

// Phase 1.5: aligned to the OpenAPI spec values. The pre-spec legacy values
// (`left`, `center_left`, `center`, `center_right`, `right`) are migrated to
// the new enum by `migrations/20260514120000-backfill-politics-enum.js`.
// Kept as a frozen array for parity with the other taxonomies, but the
// runtime source of truth for validation is now the zod `Politics` schema in
// `validators/generated/schemas.js`.
const POLITICS = freeze([
  'liberal',
  'moderate',
  'conservative',
  'not_political',
  'prefer_not_to_say',
]);

// -------- Vices --------
// Used by drinking / smoking / marijuana / drugs sub-fields.
const VICE_LEVELS = freeze(['yes', 'sometimes', 'rarely', 'no', 'prefer_not_to_say']);

// -------- Boost --------
const BOOST_LEVEL = freeze(['none', 'bronze', 'silver', 'gold']);
// Paid tiers only (used by the purchase validator — 'none' is not buyable).
const BOOST_PAID_TIERS = freeze(['bronze', 'silver', 'gold']);

// -------- Top-N dictionaries (multi-hot in ideal-match) --------
const INTERESTS_TOP_30 = freeze([
  'Travel', 'Cooking', 'Reading', 'Music', 'Movies', 'Fitness', 'Yoga', 'Hiking',
  'Photography', 'Art', 'Dancing', 'Gaming', 'Coffee', 'Wine', 'Food', 'Fashion',
  'Sports', 'Pets', 'Beach', 'Coding', 'Writing', 'Theatre', 'Concerts',
  'Running', 'Cycling', 'Swimming', 'Volunteering', 'Meditation', 'Podcasts',
  'Astrology',
]);
const LANGUAGES_TOP_10 = freeze([
  'English', 'Hindi', 'Spanish', 'Mandarin', 'French', 'Arabic', 'Portuguese',
  'Bengali', 'Russian', 'Japanese',
]);

// Ethnicity — the User model stores this as free-form strings, max 3, max 50
// chars each. No closed list exists in the codebase today. The values below
// are SUGGESTIONS only (for OpenAPI / future client pickers). The profile
// validator does NOT use this as a closed enum.
const ETHNICITY = freeze([
  'Asian',
  'Black',
  'Hispanic_Latino',
  'Middle_Eastern',
  'Native_American',
  'Pacific_Islander',
  'South_Asian',
  'White',
  'Mixed',
  'Other',
]);

// -------- Moderation --------
const REPORT_REASONS = freeze([
  'harassment',
  'spam',
  'fake',
  'inappropriate',
  'underage',
  'other',
]);
const REPORT_STATUS = freeze(['pending', 'resolved', 'dismissed']);

// -------- Likes / matches --------
const LIKE_STATUS = freeze(['pending', 'accepted', 'rejected', 'skipped']);
const LIKE_TYPE = freeze(['like', 'super']);

// -------- Selfie review --------
const SELFIE_REVIEW_STATUS = freeze(['none', 'pending', 'approved', 'rejected']);

// -------- User role --------
const USER_ROLE = freeze(['user', 'admin']);

module.exports = {
  GENDER,
  GENDER_PREFERENCE,
  ORIENTATION,
  PRONOUNS,
  EXERCISE,
  ZODIAC,
  CHILDREN,
  FAMILY_PLANS,
  DATING_INTENTIONS,
  RELATIONSHIP_TYPE,
  RELIGION,
  POLITICS,
  VICE_LEVELS,
  BOOST_LEVEL,
  BOOST_PAID_TIERS,
  INTERESTS_TOP_30,
  LANGUAGES_TOP_10,
  ETHNICITY,
  REPORT_REASONS,
  REPORT_STATUS,
  LIKE_STATUS,
  LIKE_TYPE,
  SELFIE_REVIEW_STATUS,
  USER_ROLE,
};
