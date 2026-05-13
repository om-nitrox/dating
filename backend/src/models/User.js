const mongoose = require('mongoose');
const {
  GENDER: GENDER_VALUES,
  GENDER_PREFERENCE: GENDER_PREFERENCE_VALUES,
  VICE_LEVELS: FREQUENCY_VALUES,
  CHILDREN: CHILDREN_VALUES,
  FAMILY_PLANS: FAMILY_PLANS_VALUES,
  DATING_INTENTIONS: DATING_INTENTIONS_VALUES,
  RELATIONSHIP_TYPE: RELATIONSHIP_TYPE_VALUES,
  EXERCISE: EXERCISE_VALUES,
  ZODIAC: ZODIAC_VALUES,
  SELFIE_REVIEW_STATUS,
  BOOST_LEVEL,
  USER_ROLE,
} = require('../domain/taxonomies');

const promptSchema = new mongoose.Schema(
  {
    question: {
      type: String, required: true, trim: true, maxlength: 120,
    },
    answer: {
      type: String, required: true, trim: true, maxlength: 225,
    },
  },
  { _id: false },
);

const mediaAssetSchema = new mongoose.Schema(
  {
    url: { type: String, required: true },
    publicId: { type: String, required: true },
  },
  { _id: false },
);

const fcmTokenSchema = new mongoose.Schema(
  {
    token: { type: String, required: true },
    deviceId: { type: String, required: true },
    addedAt: { type: Date, default: Date.now },
  },
  { _id: false },
);

// All enum values come from the canonical `src/domain/taxonomies.js`
// module (destructured at the top of this file). Aliased locally to the
// original `*_VALUES` names so the rest of the schema reads naturally.

const userSchema = new mongoose.Schema(
  {
    // -------- identity --------
    email: {
      type: String,
      unique: true,
      lowercase: true,
      trim: true,
    },
    googleId: {
      type: String,
      sparse: true,
    },
    name: {
      type: String,
      trim: true,
      maxlength: 50,
    },
    age: {
      type: Number,
      min: 18,
      max: 100,
    },
    dob: {
      type: Date,
    },
    gender: {
      type: String,
      enum: GENDER_VALUES,
    },
    pronouns: {
      type: [String],
      default: [],
      validate: [(v) => v.length <= 3, 'Maximum 3 pronouns'],
    },
    orientation: {
      type: [String],
      default: [],
      validate: [(v) => v.length <= 3, 'Maximum 3 orientations'],
    },

    // -------- profile content --------
    bio: {
      type: String,
      maxlength: 300,
    },
    exercise: {
      type: String,
      enum: EXERCISE_VALUES,
    },
    zodiac: {
      type: String,
      enum: ZODIAC_VALUES,
    },
    interests: [{ type: String, trim: true }],
    photos: [mediaAssetSchema],
    prompts: {
      type: [promptSchema],
      default: [],
      validate: [(v) => v.length <= 3, 'Maximum 3 prompts'],
    },

    // -------- vitals --------
    height: {
      type: Number,
      min: 120,
      max: 250,
    },
    ethnicity: {
      type: [String],
      default: [],
      validate: [(v) => v.length <= 3, 'Maximum 3 ethnicities'],
    },
    children: {
      type: String,
      enum: CHILDREN_VALUES,
    },
    familyPlans: {
      type: String,
      enum: FAMILY_PLANS_VALUES,
    },

    // -------- virtues --------
    hometown: { type: String, trim: true, maxlength: 80 },
    jobTitle: { type: String, trim: true, maxlength: 80 },
    workplace: { type: String, trim: true, maxlength: 80 },
    education: { type: String, trim: true, maxlength: 80 },
    religion: { type: String, trim: true, maxlength: 40 },
    politics: { type: String, trim: true, maxlength: 40 },
    languages: {
      type: [String],
      default: [],
      validate: [(v) => v.length <= 5, 'Maximum 5 languages'],
    },
    datingIntentions: {
      type: String,
      enum: DATING_INTENTIONS_VALUES,
    },
    relationshipType: {
      type: String,
      enum: RELATIONSHIP_TYPE_VALUES,
    },

    // -------- vices --------
    vices: {
      drinking: { type: String, enum: FREQUENCY_VALUES },
      smoking: { type: String, enum: FREQUENCY_VALUES },
      marijuana: { type: String, enum: FREQUENCY_VALUES },
      drugs: { type: String, enum: FREQUENCY_VALUES },
    },

    // -------- location --------
    // Default `coordinates` is intentionally undefined — [0, 0] is a real
    // place (Gulf of Guinea) and was poisoning $geoNear results.  We also
    // leave `type` un-defaulted so a user with no location at all stores
    // location={} (no GeoJSON object), avoiding 2dsphere index errors on
    // insert (the index is sparse, see below).
    location: {
      type: {
        type: String,
        enum: ['Point'],
      },
      coordinates: {
        type: [Number],
        default: undefined,
      },
      city: String,
      state: String,
    },

    // -------- preferences --------
    preferences: {
      ageMin: { type: Number, default: 18, min: 18 },
      ageMax: { type: Number, default: 50, max: 100 },
      maxDistance: { type: Number, default: 50 },
      genderPreference: {
        type: String,
        enum: GENDER_PREFERENCE_VALUES,
      },
    },

    // -------- verification --------
    selfiePhoto: {
      type: mediaAssetSchema,
      default: null,
    },
    isVerified: {
      type: Boolean,
      default: false,
    },
    // Selfie moderation pipeline state. `isVerified` is ONLY set to true after
    // manual (or future automated) face-match review approves the selfie.
    selfieReviewStatus: {
      type: String,
      enum: SELFIE_REVIEW_STATUS,
      default: 'none',
    },

    // -------- status --------
    daysWithoutMatch: {
      type: Number,
      default: 0,
    },
    boostLevel: {
      type: String,
      enum: BOOST_LEVEL,
      default: 'none',
    },
    boostExpiry: {
      type: Date,
    },

    // -------- notifications (multi-device) --------
    fcmTokens: {
      type: [fcmTokenSchema],
      default: [],
    },

    // -------- auth --------
    // Legacy single-session refresh token hash. Kept for backward-compat:
    // when an old client refreshes for the first time after the migration,
    // we read this, then move them onto `refreshSessions` (multi-device).
    refreshToken: {
      type: String,
    },
    // Multi-device session list. Each entry tracks a refresh-token "family"
    // for a single device. On rotation we update the entry in-place. On
    // mismatch (suspected reuse) we revoke ONLY that entry, not all sessions.
    refreshSessions: {
      type: [
        new mongoose.Schema(
          {
            jti: { type: String, required: true },
            hash: { type: String, required: true },
            deviceId: { type: String },
            createdAt: { type: Date, default: Date.now },
            expiresAt: { type: Date, required: true },
          },
          { _id: false },
        ),
      ],
      default: [],
    },

    // -------- moderation --------
    banned: {
      type: Boolean,
      default: false,
    },
    role: {
      type: String,
      enum: USER_ROLE,
      default: 'user',
    },

    // -------- computed --------
    isProfileComplete: {
      type: Boolean,
      default: false,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
  },
  {
    timestamps: true,
  },
);

// -------- Indexes --------
// Geo queries for feed.  `sparse: true` so users without coordinates don't
// hit a "Point must be an array" insert error (legacy default was [0,0]; we
// stopped defaulting it in fix 30). Mongo skips docs missing the field.
userSchema.index({ location: '2dsphere' }, { sparse: true });
userSchema.index({ gender: 1, isActive: 1, isProfileComplete: 1 });

// Boost / feed scoring
userSchema.index({ boostLevel: 1, boostExpiry: 1 });
userSchema.index({ daysWithoutMatch: -1 });

module.exports = mongoose.model('User', userSchema);

// Backward-compatibility shim. The canonical source for these arrays is
// `src/domain/taxonomies.js`; new code should import from there directly.
// Kept here in case any external script (seed.js, ad-hoc admin tooling)
// still reads `require('../models/User').enums`.
module.exports.enums = {
  GENDER_VALUES,
  GENDER_PREFERENCE_VALUES,
  FREQUENCY_VALUES,
  CHILDREN_VALUES,
  FAMILY_PLANS_VALUES,
  DATING_INTENTIONS_VALUES,
  RELATIONSHIP_TYPE_VALUES,
  EXERCISE_VALUES,
  ZODIAC_VALUES,
};
