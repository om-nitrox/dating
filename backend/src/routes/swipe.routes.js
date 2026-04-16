const { Router } = require('express');
const swipeController = require('../controllers/swipe.controller');
const { validate } = require('../middleware/validate.middleware');
const { likeLimiter, undoLimiter } = require('../middleware/rateLimiter.middleware');
const { swipeSchema } = require('../validators/swipe.validator');

const router = Router();

router.get('/feed', swipeController.getFeed);
router.post('/like', likeLimiter, validate(swipeSchema), swipeController.like);
router.post('/skip', likeLimiter, validate(swipeSchema), swipeController.skip);
router.post('/undo', undoLimiter, swipeController.undoLastSkip);

module.exports = router;
