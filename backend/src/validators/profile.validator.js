const Joi = require('joi');

const updateProfileSchema = Joi.object({
  name: Joi.string().trim().max(50),
  age: Joi.number().integer().min(18).max(100),
  gender: Joi.string().valid('male', 'female'),
  bio: Joi.string().max(300).allow(''),
  interests: Joi.array().items(Joi.string().trim()).max(20),
  location: Joi.object({
    coordinates: Joi.array().items(Joi.number()).length(2),
    city: Joi.string().max(100),
    state: Joi.string().max(100),
  }),
  preferences: Joi.object({
    ageMin: Joi.number().integer().min(18).max(100),
    ageMax: Joi.number().integer().min(18).max(100),
    maxDistance: Joi.number().integer().min(1).max(500),
  }),
  fcmToken: Joi.string().allow(''),
});

const reorderPhotosSchema = Joi.object({
  photoIds: Joi.array()
    .items(Joi.string().trim().required())
    .min(1)
    .max(6)
    .required(),
});

module.exports = { updateProfileSchema, reorderPhotosSchema };
