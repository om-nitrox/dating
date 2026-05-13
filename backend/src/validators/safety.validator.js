// Phase 0.3 note: spec-side equivalents are ./generated/requests.js
// `reportUser` (uses ReportUserRequest) and `blockUser` (uses UserIdRequest).
// The Joi versions stay; both pull from the canonical REPORT_REASONS list.
const Joi = require('joi');
const { REPORT_REASONS } = require('../domain/taxonomies');

const reportSchema = Joi.object({
  userId: Joi.string().required(),
  reason: Joi.string()
    .valid(...REPORT_REASONS)
    .required(),
  details: Joi.string().max(500).allow(''),
});

const blockSchema = Joi.object({
  userId: Joi.string().required(),
});

module.exports = { reportSchema, blockSchema };
