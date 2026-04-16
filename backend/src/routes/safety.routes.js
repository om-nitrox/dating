const { Router } = require('express');
const safetyController = require('../controllers/safety.controller');
const { validate } = require('../middleware/validate.middleware');
const { reportSchema, blockSchema } = require('../validators/safety.validator');

const router = Router();

router.post('/report', validate(reportSchema), safetyController.reportUser);
router.post('/block', validate(blockSchema), safetyController.blockUser);

module.exports = router;
