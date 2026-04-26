const Joi = require('joi');
const User = require('../models/User');

const {
  GENDER_VALUES,
  GENDER_PREFERENCE_VALUES,
  FREQUENCY_VALUES,
  CHILDREN_VALUES,
  FAMILY_PLANS_VALUES,
  DATING_INTENTIONS_VALUES,
  RELATIONSHIP_TYPE_VALUES,
} = User.enums;

// Allow clients to explicitly clear optional fields by sending null.
const nullableString = (max) =>
  Joi.string().trim().max(max).allow('', null);

const promptSchema = Joi.object({
  question: Joi.string().trim().max(120).required(),
  answer: Joi.string().trim().max(225).required(),
});

const updateProfileSchema = Joi.object({
  // identity
  name: Joi.string().trim().min(1).max(50),
  // dob as ISO date string; server will derive age
  dob: Joi.date().iso().less('now'),
  age: Joi.number().integer().min(18).max(100),
  gender: Joi.string().valid(...GENDER_VALUES),
  pronouns: Joi.array().items(Joi.string().trim().max(20)).max(3),
  orientation: Joi.array().items(Joi.string().trim().max(30)).max(3),

  // profile content
  bio: nullableString(300),
  interests: Joi.array().items(Joi.string().trim()).max(20),
  prompts: Joi.array().items(promptSchema).max(3),

  // vitals
  height: Joi.number().integer().min(120).max(250),
  ethnicity: Joi.array().items(Joi.string().trim().max(50)).max(3),
  children: Joi.string().valid(...CHILDREN_VALUES),
  familyPlans: Joi.string().valid(...FAMILY_PLANS_VALUES),

  // virtues
  hometown: nullableString(80),
  jobTitle: nullableString(80),
  workplace: nullableString(80),
  education: nullableString(80),
  religion: nullableString(40),
  politics: nullableString(40),
  languages: Joi.array().items(Joi.string().trim().max(40)).max(5),
  datingIntentions: Joi.string().valid(...DATING_INTENTIONS_VALUES),
  relationshipType: Joi.string().valid(...RELATIONSHIP_TYPE_VALUES),

  // vices — nested object with optional sub-keys
  vices: Joi.object({
    drinking: Joi.string().valid(...FREQUENCY_VALUES),
    smoking: Joi.string().valid(...FREQUENCY_VALUES),
    marijuana: Joi.string().valid(...FREQUENCY_VALUES),
    drugs: Joi.string().valid(...FREQUENCY_VALUES),
  }),

  // location
  location: Joi.object({
    coordinates: Joi.array().items(Joi.number()).length(2),
    city: Joi.string().max(100),
    state: Joi.string().max(100),
  }),

  // preferences
  preferences: Joi.object({
    ageMin: Joi.number().integer().min(18).max(100),
    ageMax: Joi.number().integer().min(18).max(100),
    maxDistance: Joi.number().integer().min(1).max(500),
    genderPreference: Joi.string().valid(...GENDER_PREFERENCE_VALUES),
  }).custom((value, helpers) => {
    if (
      value.ageMin !== undefined &&
      value.ageMax !== undefined &&
      value.ageMin > value.ageMax
    ) {
      return helpers.error('any.invalid', {
        message: 'ageMin must be ≤ ageMax',
      });
    }
    return value;
  }),

  fcmToken: Joi.string().allow(''),
}).min(1); // must update at least one field

const reorderPhotosSchema = Joi.object({
  photoIds: Joi.array()
    .items(Joi.string().trim().required())
    .min(1)
    .max(6)
    .required(),
});

module.exports = { updateProfileSchema, reorderPhotosSchema };
