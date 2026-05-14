const { Router } = require('express');
const matchController = require('../controllers/match.controller');
const { mutationLimiter } = require('../middleware/rateLimiter.middleware');
const validateObjectId = require('../middleware/validateObjectId.middleware');
const { idempotency } = require('../middleware/idempotency.middleware');

const router = Router();

router.get('/', matchController.getMatches);
// Phase 1.4: idempotency on DELETE /matches/:matchId — retries should not
// flip ?already-deleted into 404.
router.delete(
  '/:matchId',
  mutationLimiter,
  validateObjectId('matchId'),
  idempotency({ routeBase: '/matches/:matchId' }),
  matchController.deleteMatch,
);

module.exports = router;
