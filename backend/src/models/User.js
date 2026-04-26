const mongoose = require('mongoose');

/**
 * Single prompt answer displayed on the profile.
 * question is the prompt text (max 120), answer is up to 225 chars (Hinge parity).
 */
const promptSchema = new mongoose.Schema(
  {
    question: { type: String, required: true, trim: true, maxlength: 120 },
    answer: { type: String, required: true, trim: true, maxlength: 225 },
  },
  { _id: false }
);

const mediaAssetSchema = new mongoose.Schema(
  {
    url: { type: String, required: true },
    publicId: { type: String, required: true },
  },
  { _id: false }
);

// Controlled vocabularies — kept in one place so validators and model stay in sync.
// Exported at the bottom for reuse in profile.validator.js.
const GENDER_VALUES = ['male', 'female', 'nonbinary'];
const GENDER_PREFERENCE_VALUES = ['men', 'women', 'everyone'];
const FREQUENCY_VALUES = ['yes', 'sometimes', 'rarely', 'no', 'prefer_not_to_say'];
const CHILDREN_VALUES = ['have', 'dont_have', 'prefer_not_to_say'];
const FAMILY_PLANS_VALUES = [
  'want',
  'dont_want',
  'open',
  'not_sure',
  'prefer_not_to_say',
];
const DATING_INTENTIONS_VALUES = [
  'life_partner',
  'long_term',
  'long_term_open_short',
  'short_term_open_long',
  'short_term',
  'new_friends',
  'figuring_out',
];
const RELATIONSHIP_TYPE_VALUES = [
  'monogamy',
  'non_monogamy',
  'open_to_exploring',
  'prefer_not_to_say',
];

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
      // Private — never projected to other users. Age is derived and shown instead.
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
    interests: [{ type: String, trim: true }],
    photos: [mediaAssetSchema],
    prompts: {
      type: [promptSchema],
      default: [],
      validate: [(v) => v.length <= 3, 'Maximum 3 prompts'],
    },

    // -------- vitals --------
    height: {
      type: Number, // centimetres
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
    location: {
      type: {
        type: String,
        enum: ['Point'],
        default: 'Point',
      },
      coordinates: {
        type: [Number], // [longitude, latitude]
        default: [0, 0],
      },
      city: String,
      state: String,
    },

    // -------- preferences --------
    preferences: {
      ageMin: { type: Number, default: 18, min: 18 },
      ageMax: { type: Number, default: 50, max: 100 },
      maxDistance: { type: Number, default: 50 }, // km
      genderPreference: {
        type: String,
        enum: GENDER_PREFERENCE_VALUES,
      },
    },

    // -------- verification --------
    selfiePhoto: {
      type: mediaAssetSchema,
      // Private — never projected to other users; used only for moderation + isVerified gating.
      default: null,
    },
    isVerified: {
      type: Boolean,
      default: false,
    },

    // -------- existing --------
    daysWithoutMatch: {
      type: Number,
      default: 0,
    },
    boostLevel: {
      type: String,
      enum: ['none', 'bronze', 'silver', 'gold'],
      default: 'none',
    },
    boostExpiry: {
      type: Date,
    },
    fcmToken: {
      type: String,
    },
    refreshToken: {
      type: String,
    },
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
  }
);

// Indexes (email index is auto-created by unique: true on the field)
userSchema.index({ location: '2dsphere' });
userSchema.index({ gender: 1, isActive: 1, isProfileComplete: 1 });
userSchema.index({ boostLevel: 1, boostExpiry: 1 }); // For expired boost cleanup cron
userSchema.index({ daysWithoutMatch: -1 }); // For feed sorting

const User = mongoose.model('User', userSchema);

module.exports = User;
module.exports.enums = {
  GENDER_VALUES,
  GENDER_PREFERENCE_VALUES,
  FREQUENCY_VALUES,
  CHILDREN_VALUES,
  FAMILY_PLANS_VALUES,
  DATING_INTENTIONS_VALUES,
  RELATIONSHIP_TYPE_VALUES,
};
