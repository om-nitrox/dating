const Joi = require('joi');

const reportSchema = Joi.object({
  userId: Joi.string().required(),
  reason: Joi.string()
    .valid('harassment', 'fake', 'inappropriate', 'spam', 'other')
    .required(),
  details: Joi.string().max(500).allow(''),
});

const blockSchema = Joi.object({
  userId: Joi.string().required(),
});

module.exports = { reportSchema, blockSchema };
