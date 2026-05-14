const { Router } = require('express');
const safetyController = require('../controllers/safety.controller');
const { validate } = require('../middleware/validate.middleware');
const { reportSchema, blockSchema } = require('../validators/safety.validator');
const { idempotency } = require('../middleware/idempotency.middleware');

const router = Router();

// Phase 1.4: idempotency on /report and /block — both are destructive actions
// (auto-suspend threshold + match deletion) that should run exactly once
// per user intent.
router.post(
  '/report',
  idempotency({ routeBase: '/report' }),
  validate(reportSchema),
  safetyController.reportUser,
);
router.post(
  '/block',
  idempotency({ routeBase: '/block' }),
  validate(blockSchema),
  safetyController.blockUser,
);

module.exports = router;
