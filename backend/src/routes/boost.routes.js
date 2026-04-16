const { Router } = require('express');
const boostController = require('../controllers/boost.controller');
const { validate } = require('../middleware/validate.middleware');
const { purchaseBoostSchema } = require('../validators/boost.validator');

const router = Router();

router.get('/plans', boostController.getPlans);
router.get('/status', boostController.getBoostStatus);
router.post('/purchase', validate(purchaseBoostSchema), boostController.purchaseBoost);

module.exports = router;
