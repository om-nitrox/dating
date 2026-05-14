const { Router } = require('express');
const swipeController = require('../controllers/swipe.controller');
const { validate } = require('../middleware/validate.middleware');
const { likeLimiter, undoLimiter } = require('../middleware/rateLimiter.middleware');
const { swipeSchema } = require('../validators/swipe.validator');
const { idempotency } = require('../middleware/idempotency.middleware');

const router = Router();

router.get('/feed', swipeController.getFeed);
// Phase 1.4: idempotency on POST /swipe/like — double-likes from network
// retries used to surface as "user already liked" errors with bad UX.
router.post(
  '/like',
  likeLimiter,
  idempotency({ routeBase: '/swipe/like' }),
  validate(swipeSchema),
  swipeController.like,
);
router.post('/skip', likeLimiter, validate(swipeSchema), swipeController.skip);
router.post('/undo', undoLimiter, swipeController.undoLastSkip);

module.exports = router;
