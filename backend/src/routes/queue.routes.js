const { Router } = require('express');
const queueController = require('../controllers/queue.controller');
const { mutationLimiter } = require('../middleware/rateLimiter.middleware');
const validateObjectId = require('../middleware/validateObjectId.middleware');
const { zodValidate } = require('../middleware/zodValidate.middleware');
const { getQueueQuery } = require('../validators/queue.validator');
const { idempotency } = require('../middleware/idempotency.middleware');

const router = Router();

// Phase 0.3: validate `?page=&limit=` via the generated zod schema.
router.get('/', zodValidate({ query: getQueueQuery }), queueController.getQueue);
// Phase 1.4: idempotency on POST /queue/accept/:likeId — duplicate accepts
// could create duplicate matches before this guard.
router.post(
  '/accept/:likeId',
  mutationLimiter,
  validateObjectId('likeId'),
  idempotency({ routeBase: '/queue/accept/:likeId' }),
  queueController.accept,
);
router.post('/reject/:likeId', mutationLimiter, validateObjectId('likeId'), queueController.reject);

module.exports = router;
